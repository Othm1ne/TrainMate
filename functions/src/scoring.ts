/* functions/src/scoring.ts */
export interface ScoreInput {
  overlap: number;       // shared sports count
  distanceKm: number;    // haversine
  levelDiff: number;     // abs(beginner=1…expert=3)
}

export function scoreMatch(i: ScoreInput): number {
  // Higher is better
  const wOverlap   = 0.6;                // 60 %
  const wDistance  = 0.3;                // 30 %
  const wLevelDiff = 0.1;                // 10 %

  const overlapScore   = i.overlap / 3;               // max 1
  const distanceScore  = Math.max(0, (25 - i.distanceKm) / 25); // 0-1
  const levelScore     = 1 - Math.min(i.levelDiff, 2) / 2;      // 1..0

  return (
    overlapScore * wOverlap +
    distanceScore * wDistance +
    levelScore   * wLevelDiff
  );
}
