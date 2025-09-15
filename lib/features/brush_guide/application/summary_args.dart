class SummaryArgs {
  final List<double> scores;  // ✅ double로 통일
  final int durationSec;

  const SummaryArgs({
    required this.scores,
    required this.durationSec,
  });
}
