import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class DriverPage extends StatelessWidget {
  const DriverPage({Key? key}) : super(key: key);

  final String statusCompleted = "terminé";

  logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  finishRide(DocumentSnapshot ride) async {
    final now = DateTime.now();
    final frFormatted =
        DateFormat("dd/MM/yyyy HH:mm", "fr_FR").format(now);

    await FirebaseFirestore.instance
        .collection("rides")
        .doc(ride.id)
        .update({
      "status": statusCompleted,
      "finishTimeUtc": now,
      "finishTimeText": frFormatted
    });
  }

  @override
  Widget build(BuildContext context) {
    String uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Panneau Chauffeur"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Se déconnecter",
            onPressed: () => logout(context),
          )
        ],
      ),

      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection("rides")
            .where("assignedDriverId", isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Erreur de chargement des courses",
                style: TextStyle(color: Colors.red),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var rides = snapshot.data!.docs;

          if (rides.isEmpty) {
            return const Center(
              child: Text("Aucune course assignée."),
            );
          }

          return ListView.builder(
            itemCount: rides.length,
            itemBuilder: (context, index) {
              var ride = rides[index];
              final data = ride.data() as Map<String, dynamic>;

              /// Safe reads (prevents crash)
              final pickupDisplay =
                  data.containsKey("pickupDateTimeText")
                      ? data["pickupDateTimeText"]
                      : "Non défini";

              final finishDisplay =
                  data.containsKey("finishTimeText")
                      ? data["finishTimeText"]
                      : "Non terminé";

              /// SAFE pickup time handling
              DateTime? pickupTime;
              if (data.containsKey("pickupDateTimeUtc") &&
                  data["pickupDateTimeUtc"] != null &&
                  data["pickupDateTimeUtc"] is Timestamp) {
                pickupTime =
                    (data["pickupDateTimeUtc"] as Timestamp).toDate();
              }

              final now = DateTime.now();

              /// Enable rules:
              /// - if already terminé → disabled
              /// - if pickupTime exists → only enable after it
              /// - if pickupTime missing → allow finishing
              bool canFinish = false;

              if (data["status"] != statusCompleted) {
                if (pickupTime == null) {
                  canFinish = true; // backward compatibility
                } else {
                  canFinish = now.isAfter(pickupTime);
                }
              }

              return Card(
                margin: const EdgeInsets.all(10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Date & Heure : $pickupDisplay",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),

                      Text("Nom du client : ${data["passengerName"] ?? ""}"),
                      Text("Téléphone du client : ${data["passengerPhone"] ?? ""}"),
                      Text("Adresse départ : ${data["pickupLocation"] ?? ""}"),
                      Text("Adresse destination : ${data["dropLocation"] ?? ""}"),
                      Text("Numéro de vol : ${data["flightNumber"] ?? ""}"),
                      Text("Nombre de personnes : ${data["personsCount"] ?? ""}"),
                      Text("Nombre de bagages : ${data["bagsCount"] ?? ""}"),
                      Text("Autres : ${data["otherNotes"] ?? ""}"),

                      const SizedBox(height: 8),

                      Text("Statut : ${data["status"]}"),
                      Text("Heure de fin : $finishDisplay"),

                      const SizedBox(height: 12),

                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: canFinish
                              ? () => finishRide(ride)
                              : null,
                          child: const Text("Terminer"),
                        ),
                      ),

                      if (!canFinish && data["status"] != statusCompleted)
                        const Padding(
                          padding: EdgeInsets.only(top: 5),
                          child: Text(
                            "Vous pouvez terminer uniquement après l’heure assignée",
                            style: TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                                fontStyle: FontStyle.italic),
                          ),
                        )
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
}
