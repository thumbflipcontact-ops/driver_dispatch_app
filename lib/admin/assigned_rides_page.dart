import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AssignedRidesPage extends StatelessWidget {
  const AssignedRidesPage({Key? key}) : super(key: key);

  final String statusAssigned = "assigné";
  final String statusStarted = "démarré";
  final String statusCompleted = "terminé";
  final String statusUnassigned = "non assigné";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Courses assignées")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("rides")
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // ✅ ALWAYS create a fresh list
          final List<QueryDocumentSnapshot> rides =
              snapshot.data!.docs.where((d) => d.exists).toList();

          if (rides.isEmpty) {
            return const Center(child: Text("Aucune course"));
          }

          // ✅ SAFE SORT (same logic as everywhere else)
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

              final String status = data["status"] ?? "";
              final String? driverId = data["assignedDriverId"];

              final bool canModify = status == statusAssigned;
              final bool canAssign = status == statusUnassigned;

              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      Text(
                        data["passengerName"] ?? "Client",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text("Téléphone : ${data["passengerPhone"] ?? "-"}"),
                      Text("Heure : ${data["pickupDateTimeText"] ?? "-"}"),
                      Text("Adresse départ : ${data["pickupLocation"] ?? "-"}"),
                      Text("Adresse destination : ${data["dropLocation"] ?? "-"}"),
                      Text("Numéro de vol : ${data["flightNumber"] ?? "-"}"),
                      Text("Nombre de personnes : ${data["personsCount"] ?? "-"}"),
                      Text("Nombre de bagages : ${data["bagsCount"] ?? "-"}"),
                      Text("Autres notes : ${data["otherNotes"] ?? "-"}"),

                      const SizedBox(height: 6),

                      Text("Statut : $status"),
                      _driverNameWidget(driverId),

                      const SizedBox(height: 8),

                      Align(
                        alignment: Alignment.centerRight,
                        child: PopupMenuButton<String>(
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: "delete",
                              child: Text("Supprimer la course"),
                            ),
                          ],
                          onSelected: (_) async {
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

  // ───────────────── DRIVER NAME ─────────────────
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
        return Text("Chauffeur : ${data["name"] ?? "Sans nom"}");
      },
    );
  }
}
