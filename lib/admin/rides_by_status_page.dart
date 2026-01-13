import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RidesByStatusPage extends StatelessWidget {
  final String status;
  final String title;
  final Color color;

  const RidesByStatusPage({
    Key? key,
    required this.status,
    required this.title,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: color,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("rides")
            .where("status", isEqualTo: status)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text("Erreur de chargement des courses"),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          DateTime now = DateTime.now();
          List<QueryDocumentSnapshot> rides = snapshot.data!.docs;

          // ─────────────────────────────────────────
          // UPCOMING = status assigné + date >= now
          // ─────────────────────────────────────────
          if (status == "assigné") {
            rides = rides.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final Timestamp? ts = data["pickupDateTimeUtc"];
              if (ts == null) return false;

              final date = ts.toDate();
              return date.isAfter(now) ||
                  date.isAtSameMomentAs(now);
            }).toList();
          }

          if (rides.isEmpty) {
            return const Center(child: Text("Aucune course"));
          }

          // ─────────────────────────────────────────
          // SAME SORTING AS AssignedRidesPage
          // ─────────────────────────────────────────
          rides.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;

            final Timestamp? aTime =
                aData["assignedAt"] ?? aData["pickupDateTimeUtc"];
            final Timestamp? bTime =
                bData["assignedAt"] ?? bData["pickupDateTimeUtc"];

            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;

            return bTime.compareTo(aTime);
          });

          return ListView.builder(
            itemCount: rides.length,
            itemBuilder: (context, index) {
              final ride = rides[index];
              final data = ride.data() as Map<String, dynamic>;
              final String? driverId = data["assignedDriverId"];

              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      /// HEADER
                      Text(
                        data["passengerName"] ?? "Client",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                          "Téléphone : ${data["passengerPhone"] ?? "-"}"),
                      Text(
                          "Heure : ${data["pickupDateTimeText"] ?? "-"}"),
                      Text(
                          "Adresse départ : ${data["pickupLocation"] ?? "-"}"),
                      Text(
                          "Adresse destination : ${data["dropLocation"] ?? "-"}"),
                      Text(
                          "Numéro de vol : ${data["flightNumber"] ?? "-"}"),
                      Text(
                          "Nombre de personnes : ${data["personsCount"] ?? "-"}"),
                      Text(
                          "Nombre de bagages : ${data["bagsCount"] ?? "-"}"),
                      Text(
                          "Autres notes : ${data["otherNotes"] ?? "-"}"),

                      const SizedBox(height: 6),

                      Text("Statut : ${data["status"] ?? "-"}"),
                      _driverNameWidget(driverId),

                      const SizedBox(height: 8),

                      /// DELETE ACTION (ALL STATUSES)
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            await FirebaseFirestore.instance
                                .collection("rides")
                                .doc(ride.id)
                                .delete();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────
  // DRIVER NAME RESOLUTION
  // ─────────────────────────────────────────
  Widget _driverNameWidget(String? driverId) {
    if (driverId == null) {
      return const Text("Chauffeur : Non assigné");
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection("users")
          .doc(driverId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Text("Chauffeur : Inconnu");
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final name = data["name"] ?? "Sans nom";

        return Text("Chauffeur : $name");
      },
    );
  }
}
