const ANALYZE_MATCH_URL = 'https://us-central1-masarapp-b9521.cloudfunctions.net/analyzeMatch'

interface MatchAnalysis {
  type_match: number
  color_match: number
  brand_match: number | null
  semantic_similarity: number
  image_similarity: number | null
  normalized_type: string
  normalized_color: string
  normalized_brand: string | null
  reasoning: string
}

export async function analyzeTextMatch(
  lost: {
    item_type: string
    color: string
    brand?: string
    description: string
  },
  found: {
    itemType: string
    color: string
    brand?: string
    description: string
  },
  _apiKey?: string
): Promise<MatchAnalysis> {
  const res = await fetch(ANALYZE_MATCH_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ lost, found }),
  })

  if (!res.ok) {
    const err = await res.json().catch(() => ({}))
    throw new Error(`analyzeMatch error: ${res.status} — ${err.details || err.error || ''}`)
  }

  const data = await res.json()
  const clean = (data.raw || '').replace(/```json|```/g, '').trim()
  return JSON.parse(clean) as MatchAnalysis
}

export async function analyzeImageMatch(
  _lostImageUrl: string,
  _foundImageUrl: string,
  _apiKey?: string
): Promise<number> {
  return 0
}