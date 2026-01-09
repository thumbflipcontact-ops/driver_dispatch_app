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
            .orderBy("assignedAt", descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
                child: Text("Erreur de chargement des courses"));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final rides = snapshot.data!.docs;

          if (rides.isEmpty) {
            return const Center(child: Text("Aucune course"));
          }

          return ListView.builder(
            itemCount: rides.length,
            itemBuilder: (context, index) {
              final ride = rides[index];
              final data = ride.data() as Map<String, dynamic>;

              final String status = data["status"] ?? "";
              final String? driverId = data["assignedDriverId"];
              final String pickupTime =
                  data["pickupDateTimeText"] ?? "Heure non définie";

              final bool canModify = status == statusAssigned;
              final bool canAssign = status == statusUnassigned;
              final bool canDelete = driverId == null;

              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(data["passengerName"] ?? "Client"),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Heure de prise en charge : $pickupTime"),
                      Text("Statut : $status"),
                      _driverNameWidget(driverId),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    itemBuilder: (context) {
                      final items = <PopupMenuEntry<String>>[];

                      if (canModify) {
                        items.add(const PopupMenuItem(
                          value: "remove",
                          child: Text("Retirer chauffeur"),
                        ));
                      }

                      if (canAssign) {
                        items.add(const PopupMenuItem(
                          value: "assign",
                          child: Text("Assigner chauffeur"),
                        ));
                      }

                      if (canDelete) {
                        items.add(const PopupMenuItem(
                          value: "delete",
                          child: Text("Supprimer la course"),
                        ));
                      }

                      return items;
                    },
                    onSelected: (value) async {
                      if (value == "remove") {
                        await FirebaseFirestore.instance
                            .collection("rides")
                            .doc(ride.id)
                            .update({
                          "assignedDriverId": null,
                          "status": statusUnassigned,
                        });
                      }

                      if (value == "assign") {
                        _showDriverPicker(context, ride.id);
                      }

                      if (value == "delete") {
                        await FirebaseFirestore.instance
                            .collection("rides")
                            .doc(ride.id)
                            .delete();
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// 🔽 Bottom sheet to pick a driver
  void _showDriverPicker(BuildContext context, String rideId) {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("users")
              .where("role", isEqualTo: "driver")
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final drivers = snapshot.data!.docs;

            if (drivers.isEmpty) {
              return const Center(child: Text("Aucun chauffeur"));
            }

            return ListView(
              children: drivers.map((driver) {
                final name = driver["name"] ?? "Sans nom";

                return ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(name),
                  onTap: () async {
                    await FirebaseFirestore.instance
                        .collection("rides")
                        .doc(rideId)
                        .update({
                      "assignedDriverId": driver.id,
                      "status": statusAssigned,
                      "assignedAt": FieldValue.serverTimestamp(),
                    });

                    Navigator.pop(context);
                  },
                );
              }).toList(),
            );
          },
        );
      },
    );
  }

  /// 🔹 Resolve driver ID → driver name
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
