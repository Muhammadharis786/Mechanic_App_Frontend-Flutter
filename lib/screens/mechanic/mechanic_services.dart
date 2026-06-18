import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MechanicServicesScreen extends StatefulWidget {
  const MechanicServicesScreen({super.key});

  @override
  State<MechanicServicesScreen> createState() => _MechanicServicesScreenState();
}

class _MechanicServicesScreenState extends State<MechanicServicesScreen>
    with SingleTickerProviderStateMixin {
  static const String _baseUrl =
      'https://mechanicapp-service-621632382478.asia-south1.run.app';

  bool _isLoading = true;

  // API data
  int totalCompleted = 0;
  int totalCancelled = 0;
  int totaljobsCompleted = 0;
  double totalEarning = 0;
  double averageRating = 0;
  int totalReviews = 0;
  double completionRate = 0;
  int activeJobs = 0;
  int dueToday = 0;
  double growthPercent = 0;
  double lastMonthEarning = 0;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fetchMyServices();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _fetchMyServices() async {
    final url = Uri.parse('$_baseUrl/api/mechanic/my-services');
    try {
      final response =
          await http.get(url, headers: UserSession().getAuthHeader());
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map) {
          setState(() {
            totalCompleted =
                (data['totalCompleted'] as num?)?.toInt() ?? 0;
            totalCancelled =
                (data['totalCancelled'] as num?)?.toInt() ?? 0;
            totaljobsCompleted =
                (data['totaljobsCompleted'] as num?)?.toInt() ?? 0;
            totalEarning =
                (data['totalEarning'] as num?)?.toDouble() ?? 0;
            averageRating =
                (data['averageRating'] as num?)?.toDouble() ?? 0;
            totalReviews =
                (data['totalReviews'] as num?)?.toInt() ?? 0;
            completionRate =
                (data['completionRate'] as num?)?.toDouble() ?? 0;
            activeJobs =
                (data['activeJobs'] as num?)?.toInt() ?? 0;
            dueToday =
                (data['dueToday'] as num?)?.toInt() ?? 0;
            growthPercent =
                (data['growthPercent'] as num?)?.toDouble() ?? 0;
            lastMonthEarning =
                (data['lastMonthEarning'] as num?)?.toDouble() ?? 0;
            _isLoading = false;
          });
          _fadeController.forward();
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching my-services: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refresh() async {
    _fadeController.reset();
    await _fetchMyServices();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary =
        isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          "My Services",
          style: GoogleFonts.poppins(
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: cardColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: primaryColor),
      ),
      body: _isLoading
          ? _buildLoadingSkeleton(isDark)
          : FadeTransition(
              opacity: _fadeAnimation,
              child: RefreshIndicator(
                onRefresh: _refresh,
                color: const Color(0xFFFB3300),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── STATS GRID (2 columns) ──
                      _buildStatsGrid(isDark, cardColor, textPrimary,
                          textSecondary),
                      const SizedBox(height: 28),

                      // ── PERFORMANCE OVERVIEW ──
                      _buildPerformanceOverview(
                          isDark, cardColor, textPrimary, textSecondary),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  // ── STATS GRID ──
  Widget _buildStatsGrid(
      bool isDark, Color cardColor, Color textPrimary, Color textSecondary) {
    return Column(
      children: [
        // Row 1: Total Jobs | Active Jobs
        Row(
          children: [
            Expanded(
              child: _statCard(
                icon: Icons.build_rounded,
                iconBgColor: const Color(0xFFFBE9E7),
                iconColor: const Color(0xFFFB3300),
                value: '$totaljobsCompleted',
                label: 'Total Jobs',
                subText:
                    '${growthPercent >= 0 ? '+' : ''}${growthPercent.toStringAsFixed(1)}% this month',
                subColor: growthPercent >= 0
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFFD32F2F),
                subIcon: growthPercent >= 0
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                isDark: isDark,
                cardColor: cardColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                icon: Icons.access_time_rounded,
                iconBgColor: const Color(0xFFFFF3E0),
                iconColor: const Color(0xFFFF9800),
                value: '$activeJobs',
                label: 'Active Jobs',
                subText: '$dueToday due today',
                subColor: const Color(0xFFFF9800),
                subIcon: Icons.circle,
                subIconSize: 8,
                isDark: isDark,
                cardColor: cardColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Row 2: Completed | Avg. Rating
        Row(
          children: [
            Expanded(
              child: _statCard(
                icon: Icons.check_circle_outline_rounded,
                iconBgColor: const Color(0xFFE8F5E9),
                iconColor: const Color(0xFF4CAF50),
                value: '$totalCompleted',
                label: 'Completed',
                subText: '${completionRate.toStringAsFixed(1)}% this month',
                subColor: const Color(0xFF2E7D32),
                subIcon: Icons.trending_up_rounded,
                isDark: isDark,
                cardColor: cardColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ratingCard(
                isDark: isDark,
                cardColor: cardColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Row 3: Cancelled Jobs (single card, full width)
        _cancelledCard(
          isDark: isDark,
          cardColor: cardColor,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
        ),
      ],
    );
  }

  // ── SINGLE STAT CARD ──
  Widget _statCard({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String value,
    required String label,
    required String subText,
    required Color subColor,
    required IconData subIcon,
    double subIconSize = 16,
    required bool isDark,
    required Color cardColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? iconColor.withValues(alpha: 0.15) : iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(subIcon, color: subColor, size: subIconSize),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  subText,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: subColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── RATING CARD ──
  Widget _ratingCard({
    required bool isDark,
    required Color cardColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.amber.withValues(alpha: 0.15)
                  : const Color(0xFFFFF9C4),
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                const Icon(Icons.star_outline_rounded, color: Colors.amber, size: 22),
          ),
          const SizedBox(height: 14),
          Text(
            averageRating.toStringAsFixed(1),
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Avg. Rating',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          // Star row
          Row(
            children: List.generate(5, (i) {
              final starValue = i + 1;
              if (averageRating >= starValue) {
                return const Icon(Icons.star_rounded,
                    color: Colors.amber, size: 18);
              } else if (averageRating > starValue - 1) {
                return const Icon(Icons.star_half_rounded,
                    color: Colors.amber, size: 18);
              } else {
                return Icon(Icons.star_outline_rounded,
                    color: Colors.grey.shade300, size: 18);
              }
            }),
          ),
          const SizedBox(height: 4),
          Text(
            '$totalReviews reviews',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ── CANCELLED JOBS CARD ──
  Widget _cancelledCard({
    required bool isDark,
    required Color cardColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.red.withValues(alpha: 0.15)
                  : const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.cancel_outlined,
                color: Color(0xFFD32F2F), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cancelled Jobs',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$totalCancelled',
                  style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.red.withValues(alpha: 0.15)
                  : const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              totalCancelled == 0 ? 'None' : '$totalCancelled total',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFD32F2F),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── PERFORMANCE OVERVIEW ──
  Widget _buildPerformanceOverview(
      bool isDark, Color cardColor, Color textPrimary, Color textSecondary) {
    final now = DateTime.now();
    final monthNames = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final monthLabel = '${monthNames[now.month]} ${now.year}';

    final earningDiff = totalEarning - lastMonthEarning;
    final isPositive = earningDiff >= 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Performance Overview',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  monthLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Total Earnings
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFFFB3300).withValues(alpha: 0.15)
                      : const Color(0xFFFBE9E7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.help_outline_rounded,
                    color: Color(0xFFFB3300), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Earnings',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'PKR ${totalEarning.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'vs last month',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPositive
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        color: isPositive
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFD32F2F),
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'PKR ${lastMonthEarning.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isPositive
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFD32F2F),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 24),
          Divider(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
            thickness: 1,
          ),
          const SizedBox(height: 16),

          // Job Completion Rate
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.bar_chart_rounded,
                      color: textSecondary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Job Completion Rate',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
              Text(
                '${completionRate.toStringAsFixed(1)}%',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2E7D32),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (completionRate / 100).clamp(0.0, 1.0),
              backgroundColor:
                  isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFFFB3300)),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 8),

          // Bottom label
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$totalCompleted of $totaljobsCompleted jobs',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: textSecondary,
                ),
              ),
              Text(
                completionRate >= 90
                    ? 'Excellent'
                    : completionRate >= 70
                        ? 'Good'
                        : completionRate >= 50
                            ? 'Average'
                            : 'Needs Improvement',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: completionRate >= 90
                      ? const Color(0xFF2E7D32)
                      : completionRate >= 70
                          ? const Color(0xFFFF9800)
                          : const Color(0xFFD32F2F),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── LOADING SKELETON ──
  Widget _buildLoadingSkeleton(bool isDark) {
    final shimmerBase =
        isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    Widget skeletonBox(double height, double width) {
      return Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: shimmerBase,
          borderRadius: BorderRadius.circular(8),
        ),
      );
    }

    Widget skeletonCard({double height = 160}) {
      return Container(
        height: height,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            skeletonBox(40, 40),
            const Spacer(),
            skeletonBox(24, 60),
            const SizedBox(height: 8),
            skeletonBox(14, 80),
            const Spacer(),
            skeletonBox(12, 100),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: skeletonCard()),
              const SizedBox(width: 12),
              Expanded(child: skeletonCard()),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: skeletonCard()),
              const SizedBox(width: 12),
              Expanded(child: skeletonCard()),
            ],
          ),
          const SizedBox(height: 12),
          skeletonCard(height: 80),
          const SizedBox(height: 28),
          Container(
            height: 220,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.grey.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                skeletonBox(18, 180),
                const Spacer(),
                skeletonBox(30, 160),
                const SizedBox(height: 16),
                skeletonBox(10, double.infinity),
                const Spacer(),
                skeletonBox(12, 120),
              ],
            ),
          ),
        ],
      ),
    );
  }
}