import { useState, useCallback, useRef } from 'react'
import { runMatchingEngine, type MatchResult } from '@/lib/matchingEngine'
import { approveMatch, confirmCollection } from '@/lib/firebase'
import { type PassengerReport, type FoundItem } from '@/data/mockData'

export interface MatchGroup {
  found: FoundItem
  matches: MatchResult[]
}

export function useMatching() {
  const [isRunning, setIsRunning] = useState(false)
  const [progress, setProgress] = useState(0)
  const [matchGroups, setMatchGroups] = useState<MatchGroup[]>(() => {
    try {
      const saved = localStorage.getItem('matchGroups')
      return saved ? JSON.parse(saved) : []
    } catch { return [] }
  })
  const [error, setError] = useState<string | null>(null)
  const lastInputKeyRef = useRef<string>(localStorage.getItem('lastInputKey') || '')

  const runMatching = useCallback(async (
    lostReports: PassengerReport[],
    foundReports: FoundItem[]
  ) => {
    const inputKey = `${lostReports.map(r => r.id).sort().join(',')}|${foundReports.map(f => f.id).sort().join(',')}`
    if (inputKey === lastInputKeyRef.current) {
      console.log('⏭️ Same data, skipping matching')
      return
    }
    lastInputKeyRef.current = inputKey
    localStorage.setItem('lastInputKey', inputKey)

    console.log('🚀 Running matching...')
    console.log('Lost reports:', lostReports.length)
    console.log('Found reports:', foundReports.length)

    if (lostReports.length === 0 || foundReports.length === 0) {
      setMatchGroups([])
      localStorage.removeItem('matchGroups')
      localStorage.removeItem('lastInputKey')
      return
    }

    setIsRunning(true)
    setError(null)
    setProgress(0)

    try {
      const total = foundReports.length * lostReports.length

      const results = await runMatchingEngine(
        lostReports,
        foundReports,
        '',
        (current, _total) => {
          setProgress(Math.round((current / total) * 100))
        }
      )

      console.log('✅ Match results:', results.length)

      const groups: MatchGroup[] = foundReports.map(found => ({
        found,
        matches: results
          .filter(r => r.found_report_id === found.id)
          .sort((a, b) => b.final_score - a.final_score)
          .slice(0, 3),
      })).filter(g => g.matches.length > 0)

      console.log('📊 Match groups:', groups.length)

      setMatchGroups(groups)
      localStorage.setItem('matchGroups', JSON.stringify(groups))
    } catch (e) {
      console.error('Matching engine error:', e)
      setError('Matching failed. Check console for details.')
    } finally {
      setIsRunning(false)
      setProgress(100)
    }
  }, [])

  const approveMatchHandler = useCallback(async (
    foundReportId: string,
    lostReportId: string
  ) => {
    try {
      await approveMatch(foundReportId, lostReportId)
      setMatchGroups(prev => {
        const updated = prev.filter(g => g.found.id !== foundReportId)
        localStorage.setItem('matchGroups', JSON.stringify(updated))
        return updated
      })
    } catch (e) {
      console.error('Approve match error:', e)
      setError('Failed to approve match.')
    }
  }, [])

  const confirmCollectionHandler = useCallback(async (
    foundReportId: string,
    lostReportId: string
  ) => {
    try {
      await confirmCollection(foundReportId, lostReportId)
    } catch (e) {
      console.error('Confirm collection error:', e)
      setError('Failed to confirm collection.')
    }
  }, [])

  return {
    isRunning,
    progress,
    matchGroups,
    error,
    runMatching,
    approveMatch: approveMatchHandler,
    confirmCollection: confirmCollectionHandler,
  }
}