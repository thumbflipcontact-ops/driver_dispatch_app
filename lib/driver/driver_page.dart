import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class DriverPage extends StatelessWidget {
  const DriverPage({Key? key}) : super(key: key);

  final String statusAssigned = "assigné";
  final String statusStarted  = "démarré";
  final String statusCompleted = "terminé";

  logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  startRide(DocumentSnapshot ride) async {
    final now = DateTime.now();
    final frFormatted =
        DateFormat("dd/MM/yyyy HH:mm", "fr_FR").format(now);

    await FirebaseFirestore.instance
        .collection("rides")
        .doc(ride.id)
        .update({
      "status": statusStarted,
      "startTimeUtc": now,
      "startTimeText": frFormatted
    });
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
            .orderBy("pickupDateTimeUtc", descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
                child: Text("Erreur de chargement des courses",
                    style: TextStyle(color: Colors.red)));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var rides = snapshot.data!.docs;

          if (rides.isEmpty) {
            return const Center(child: Text("Aucune course trouvée."));
          }

          /// Split Active vs History
          final activeRides = rides.where((r) {
            return r["status"] != statusCompleted;
          }).toList();

          final historyRides = rides.where((r) {
            return r["status"] == statusCompleted || r["status"] == statusStarted;
          }).toList();

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ---------------- ACTIVE RIDES ----------------
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    "Courses Actives",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700),
                  ),
                ),

                if (activeRides.isEmpty)
                  const Center(
                      child: Padding(
                        padding: EdgeInsets.all(10),
                        child: Text("Aucune course active."),
                      )),

                ...activeRides.map((ride) => _activeRideCard(context, ride)),

                const SizedBox(height: 20),

                // ---------------- HISTORY ----------------
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    "Historique des courses",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700),
                  ),
                ),

                if (historyRides.isEmpty)
                  const Center(
                      child: Padding(
                        padding: EdgeInsets.all(10),
                        child: Text("Aucun historique disponible."),
                      )),

                ...historyRides.map((ride) => _historyCard(ride)),
              ],
            ),
          );
        },
      ),
    );
  }

  /// ================= ACTIVE CARD =================
  Widget _activeRideCard(BuildContext context, DocumentSnapshot ride) {
    final data = ride.data() as Map<String, dynamic>;

    final pickupDisplay = data["pickupDateTimeText"] ?? "Non défini";

    final finishDisplay =
        data["finishTimeText"] ?? "Non terminé";

    DateTime? pickupTime;
    if (data["pickupDateTimeUtc"] is Timestamp) {
      pickupTime = (data["pickupDateTimeUtc"] as Timestamp).toDate();
    }

    final now = DateTime.now();

    bool canStart = false;
    if (data["status"] == statusAssigned) {
      if (pickupTime == null) {
        canStart = true;
      } else {
        canStart = now.isAfter(pickupTime);
      }
    }

    bool canFinish = (data["status"] == statusStarted);

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

            const SizedBox(height: 10),

            Text("Statut : ${data["status"]}"),
            Text("Heure de fin : $finishDisplay"),

            const SizedBox(height: 14),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: canStart ? () => startRide(ride) : null,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange),
                  child: const Text("Démarrer"),
                ),
                ElevatedButton(
                  onPressed: canFinish ? () => finishRide(ride) : null,
                  child: const Text("Terminer"),
                ),
              ],
            ),

            if (!canStart && data["status"] == statusAssigned)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  "Vous pouvez démarrer uniquement après l’heure assignée",
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
  }

  /// ================= HISTORY CARD =================
  Widget _historyCard(DocumentSnapshot ride) {
    final data = ride.data() as Map<String, dynamic>;

    return Card(
      color: Colors.grey.shade100,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Client : ${data["passengerName"] ?? ""}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text("Date : ${data["pickupDateTimeText"] ?? ""}"),
            Text("Statut final : ${data["status"]}"),
            if (data["finishTimeText"] != null)
              Text("Terminé à : ${data["finishTimeText"]}"),
          ],
        ),
      ),
    );
  }
}
