import { analyzeTextMatch, analyzeImageMatch } from './gptApi'

// Weights based on available data
type WeightSet = {
  image?: number
  semantic: number
  type: number
  color: number
  brand?: number
  location: number
  time: number
}

const WEIGHTS: Record<string, WeightSet> = {
  WITH_IMAGE_AND_BRAND: {
    image: 0.30,
    semantic: 0.25,
    type: 0.15,
    color: 0.10,
    brand: 0.10,
    location: 0.05,
    time: 0.05,
  },
  WITH_IMAGE_NO_BRAND: {
    image: 0.35,
    semantic: 0.30,
    type: 0.15,
    color: 0.10,
    location: 0.05,
    time: 0.05,
  },
  NO_IMAGE_WITH_BRAND: {
    semantic: 0.35,
    type: 0.20,
    brand: 0.15,
    color: 0.15,
    location: 0.10,
    time: 0.05,
  },
  NO_IMAGE_NO_BRAND: {
    semantic: 0.45,
    type: 0.25,
    color: 0.15,
    location: 0.10,
    time: 0.05,
  },
}

// Calculate time score based on hours difference
function calculateTimeScore(lostDatetime: string, foundDatetime: string): number {
  if (!lostDatetime || !foundDatetime) return 50

  const lost = new Date(lostDatetime).getTime()
  const found = new Date(foundDatetime).getTime()
  const hours = Math.abs(found - lost) / (1000 * 60 * 60)

  if (hours <= 6)  return 100
  if (hours <= 24) return 80
  if (hours <= 72) return 50
  return 20
}

// Calculate location score
function calculateLocationScore(lostStationId: string, foundStationId: string): number {
  if (!lostStationId || !foundStationId) return 0
  return lostStationId === foundStationId ? 100 : 0
}

// Determine which weights to use based on available data
function getWeights(hasImage: boolean, hasBrand: boolean): WeightSet {
  if (hasImage && hasBrand)  return WEIGHTS.WITH_IMAGE_AND_BRAND
  if (hasImage && !hasBrand) return WEIGHTS.WITH_IMAGE_NO_BRAND
  if (!hasImage && hasBrand) return WEIGHTS.NO_IMAGE_WITH_BRAND
  return WEIGHTS.NO_IMAGE_NO_BRAND
}

// Main matching function
export interface MatchResult {
  lost_report_id: string
  found_report_id: string
  final_score: number
  type_match: number
  color_match: number
  brand_match: number | null
  semantic_similarity: number
  image_similarity: number | null
  location_score: number
  time_score: number
  normalized_type: string
  normalized_color: string
  normalized_brand: string | null
  reasoning: string
  confidence: 'high' | 'medium' | 'low'
}

export async function calculateMatch(
  lost: any,
  found: any,
  apiKey: string
): Promise<MatchResult> {

  // Check available data
  const hasImage = !!(lost.photo_url && found.imageUrl)
  const hasBrand = !!(lost.brand && found.brand)

  // Get GPT text analysis
  const gptResult = await analyzeTextMatch(
    {
      item_type: lost.item_type || lost.itemType || '',
      color: lost.color || '',
      brand: lost.brand || '',
      description: lost.description || '',
    },
    {
      itemType: found.itemType || found.item_type || '',
      color: found.color || '',
      brand: found.brand || '',
      description: found.description || '',
    },
    apiKey
  )

  // Get image similarity if both have images
  let imageSimilarity: number | null = null
  if (hasImage) {
    try {
      imageSimilarity = await analyzeImageMatch(
        lost.photo_url,
        found.imageUrl,
        apiKey
      )
    } catch (e) {
      console.error('Image analysis failed:', e)
      imageSimilarity = null
    }
  }

  // Calculate location and time scores
  const locationScore = calculateLocationScore(
    lost.station_id || '',
    found.station_id || ''
  )

  // Build found datetime from date + time
  const foundDatetime = found.date && found.time
    ? `${found.date}T${found.time}:00`
    : ''

  const timeScore = calculateTimeScore(
    lost.lost_datetime || '',
    foundDatetime
  )

  // Get weights based on available data
  const weights = getWeights(hasImage, hasBrand)

  // Calculate final score
  let finalScore = 0

  if (weights.image !== undefined && imageSimilarity !== null) {
    finalScore += imageSimilarity * weights.image
  }

  finalScore += gptResult.semantic_similarity * weights.semantic
  finalScore += gptResult.type_match * weights.type
  finalScore += gptResult.color_match * weights.color

  if (weights.brand !== undefined && gptResult.brand_match !== null) {
    finalScore += gptResult.brand_match * weights.brand
  }

  finalScore += locationScore * weights.location
  finalScore += timeScore * weights.time

  const score = Math.round(finalScore)

  return {
    lost_report_id: lost.id,
    found_report_id: found.id,
    final_score: score,
    type_match: gptResult.type_match,
    color_match: gptResult.color_match,
    brand_match: gptResult.brand_match,
    semantic_similarity: gptResult.semantic_similarity,
    image_similarity: imageSimilarity,
    location_score: locationScore,
    time_score: timeScore,
    normalized_type: gptResult.normalized_type,
    normalized_color: gptResult.normalized_color,
    normalized_brand: gptResult.normalized_brand,
    reasoning: gptResult.reasoning,
    confidence: score >= 80 ? 'high' : score >= 50 ? 'medium' : 'low',
  }
}

// Run matching for all found reports against all lost reports
export async function runMatchingEngine(
  lostReports: any[],
  foundReports: any[],
  apiKey: string,
  onProgress?: (current: number, total: number) => void
): Promise<MatchResult[]> {

  const results: MatchResult[] = []
  const total = foundReports.length * lostReports.length
  let current = 0

  for (const found of foundReports) {
    for (const lost of lostReports) {
      try {
        const match = await calculateMatch(lost, found, apiKey)

        // Only keep matches above 50%
        if (match.final_score >= 50) {
          results.push(match)
        }
      } catch (e) {
        console.error(`Match failed: ${lost.id} vs ${found.id}`, e)
      }

      current++
      onProgress?.(current, total)
    }
  }

  // Sort by score descending
  return results.sort((a, b) => b.final_score - a.final_score)
}