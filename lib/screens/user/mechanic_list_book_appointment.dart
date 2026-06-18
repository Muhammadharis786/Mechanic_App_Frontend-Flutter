import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class MechanicListScreenn extends StatelessWidget {
  final String serviceType;
  final List<Map<String, dynamic>> mechanics;
  final String? selectedMechanicId;
  final bool showViewOption;

  const MechanicListScreenn({
    super.key,
    required this.serviceType,
    required this.mechanics,
    this.selectedMechanicId,
    required this.showViewOption,
  });

  final Color primaryColor = const Color(0xFFFB3300);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFFFB3300),
            size: 18,
          ),
          splashRadius: 20,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Nearby Mechanics",
              style: TextStyle(
                  fontFamily: 'Bricolage Grotesque',
                  color: Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.w500),
            ),
            Text(serviceType,
                style: const TextStyle(
                    fontFamily: 'Bricolage Grotesque',
                    fontSize: 13,
                    color: Colors.grey,
                    fontWeight: FontWeight.w400)),
          ],
        ),
      ),
      body: mechanics.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.engineering_outlined,
                      size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    "No mechanics found nearby",
                    style: TextStyle(
                        fontFamily: 'Bricolage Grotesque',
                        color: Colors.grey.shade500,
                        fontSize: 14),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: mechanics.length,
              itemBuilder: (context, index) {
                final mechanic = mechanics[index];
                final isSelected = selectedMechanicId != null &&
                    selectedMechanicId == mechanic['phonenumber'];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: _mechanicCard(mechanic, isSelected, context),
                );
              },
            ),
    );
  }

  Widget _mechanicCard(
      Map<String, dynamic> mechanic, bool isSelected, BuildContext context) {
    final name = mechanic['name'] as String? ?? 'Unknown Mechanic';
    final rating =
        (mechanic['averagerating'] as num?)?.toStringAsFixed(1) ?? '5.0';
    final distance =
        (mechanic['distance'] as num?)?.toStringAsFixed(1) ?? '--';
    final isActive = mechanic['isactive'] as bool? ?? false;
    final isEngaged = mechanic['isengaged'] as bool? ?? false;
    final phone = mechanic['phonenumber'] as String? ?? '';
    final imgUrl = mechanic['mechanicimgurl'] as String?;
    final mechanicType = mechanic['MechanicType'] as String?;
    final locName = mechanic['mechaniclocname'] as String?;

    Color statusColor;
    String statusLabel;
    if (!isActive) {
      statusColor = Colors.grey;
      statusLabel = 'Offline';
    } else if (isEngaged) {
      statusColor = Colors.orange;
      statusLabel = 'Busy';
    } else {
      statusColor = Colors.green;
      statusLabel = 'Available';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isSelected ? primaryColor : Colors.grey.shade200, width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: imgUrl != null ? NetworkImage(imgUrl) : null,
                child: imgUrl == null
                    ? Icon(Icons.engineering, color: primaryColor, size: 26)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontFamily: 'Bricolage Grotesque',
                            fontWeight: FontWeight.w500,
                            fontSize: 14)),
                    const SizedBox(height: 2),
                    if (mechanicType != null)
                      Text(mechanicType,
                          style: TextStyle(
                              fontFamily: 'Bricolage Grotesque',
                              fontSize: 11,
                              color: primaryColor)),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 14, color: Colors.amber),
                        const SizedBox(width: 3),
                        Text(rating,
                            style: const TextStyle(
                                fontFamily: 'Bricolage Grotesque',
                                fontSize: 12,
                                fontWeight: FontWeight.w400)),
                        const SizedBox(width: 8),
                        Icon(Icons.location_on_outlined,
                            size: 14, color: primaryColor),
                        Text("$distance km",
                            style: const TextStyle(
                                fontFamily: 'Bricolage Grotesque',
                                fontSize: 12,
                                fontWeight: FontWeight.w400)),
                      ],
                    ),
                    if (locName != null) ...[
                      const SizedBox(height: 2),
                      Text(locName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontFamily: 'Bricolage Grotesque',
                              fontSize: 11,
                              color: Colors.grey.shade600)),
                    ]
                  ],
                ),
              ),
              // Status badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                            color: statusColor, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text(statusLabel,
                        style: TextStyle(
                            fontFamily: 'Bricolage Grotesque',
                            fontSize: 11,
                            color: statusColor,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, mechanic);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(isSelected ? "Selected" : "Select",
                    style: const TextStyle(
                        fontFamily: 'Bricolage Grotesque',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white)),
              ),
              ElevatedButton.icon(
                onPressed: phone.isNotEmpty ? () => _callMechanic(phone) : null,
                icon: const Icon(Icons.call_outlined,
                    size: 16, color: Colors.white),
                label: const Text("Call",
                    style: TextStyle(color: Colors.white, fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.lightGreen,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _callMechanic(String phone) async {
    final Uri uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
