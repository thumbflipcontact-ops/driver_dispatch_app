import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class DriverPage extends StatelessWidget {
  const DriverPage({Key? key}) : super(key: key);

  final String statusAssigned = "assigné";
  final String statusStarted = "démarré";
  final String statusCompleted = "terminé";
  final String statusUnassigned = "non assigné";

  logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  /// 🚫 Cannot start if pickup time is in the future
  startRide(BuildContext context, DocumentSnapshot ride) async {
    final data = ride.data() as Map<String, dynamic>;

    DateTime now = DateTime.now();
    DateTime? pickupTime;

    if (data["pickupDateTimeUtc"] is Timestamp) {
      pickupTime =
          (data["pickupDateTimeUtc"] as Timestamp).toDate();
    }

    if (pickupTime != null && pickupTime.isAfter(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "Vous pouvez démarrer uniquement à l’heure de prise en charge"),
        ),
      );
      return;
    }

    await FirebaseFirestore.instance
        .collection("rides")
        .doc(ride.id)
        .update({
      "status": statusStarted,
      "startTimeUtc": now,
      "startTimeText":
          DateFormat("dd/MM/yyyy HH:mm", "fr_FR").format(now),
    });
  }

  finishRide(DocumentSnapshot ride) async {
    final now = DateTime.now();

    await FirebaseFirestore.instance
        .collection("rides")
        .doc(ride.id)
        .update({
      "status": statusCompleted,
      "finishTimeUtc": now,
      "finishTimeText":
          DateFormat("dd/MM/yyyy HH:mm", "fr_FR").format(now),
    });
  }

  /// ❌ Prevent unassign if ride already started
  unassignRide(BuildContext context, DocumentSnapshot ride) async {
    final data = ride.data() as Map<String, dynamic>;

    if (data["status"] != statusAssigned) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text("Impossible de supprimer une course déjà démarrée"),
        ),
      );
      return;
    }

    await FirebaseFirestore.instance
        .collection("rides")
        .doc(ride.id)
        .update({
      "assignedDriverId": null,
      "status": statusUnassigned,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Course retirée")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Panneau Chauffeur"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => logout(context),
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("rides")
            .where("assignedDriverId", isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
                child: Text("Aucune course assignée."));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          List<DocumentSnapshot> rides = snapshot.data!.docs;

          if (rides.isEmpty) {
            return const Center(
                child: Text("Aucune course assignée."));
          }

          /// ✅ Sort locally by pickup time (ascending)
          rides.sort((a, b) {
            final aTime = a["pickupDateTimeUtc"];
            final bTime = b["pickupDateTimeUtc"];

            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;

            return (aTime as Timestamp)
                .toDate()
                .compareTo((bTime as Timestamp).toDate());
          });

          final activeRides =
              rides.where((r) => r["status"] != statusCompleted).toList();

          final historyRides =
              rides.where((r) => r["status"] == statusCompleted).toList();

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    "Courses Actives",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),

                if (activeRides.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(10),
                    child: Text("Aucune course active."),
                  ),

                ...activeRides.map(
                    (ride) => _activeRideCard(context, ride)),

                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    "Historique des courses",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),

                if (historyRides.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(10),
                    child: Text("Aucun historique disponible."),
                  ),

                ...historyRides.map((ride) => _historyCard(ride)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _activeRideCard(BuildContext context, DocumentSnapshot ride) {
    final data = ride.data() as Map<String, dynamic>;

    DateTime? pickupTime;
    if (data["pickupDateTimeUtc"] is Timestamp) {
      pickupTime =
          (data["pickupDateTimeUtc"] as Timestamp).toDate();
    }

    final now = DateTime.now();
    final bool canStart =
        data["status"] == statusAssigned &&
        (pickupTime == null || !pickupTime.isAfter(now));

    final bool canFinish = data["status"] == statusStarted;
    final bool canUnassign = data["status"] == statusAssigned;

    return Card(
      margin: const EdgeInsets.all(10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Date & Heure : ${data["pickupDateTimeText"] ?? ""}",
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text("Client : ${data["passengerName"] ?? ""}"),
            Text("Départ : ${data["pickupLocation"] ?? ""}"),
            Text("Destination : ${data["dropLocation"] ?? ""}"),
            Text("Statut : ${data["status"]}"),

            const SizedBox(height: 12),

            Row(
              children: [
                ElevatedButton(
                  onPressed:
                      canStart ? () => startRide(context, ride) : null,
                  child: const Text("Démarrer"),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed:
                      canFinish ? () => finishRide(ride) : null,
                  child: const Text("Terminer"),
                ),
              ],
            ),

            if (!canStart && data["status"] == statusAssigned)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  "Vous pouvez démarrer uniquement à l’heure prévue",
                  style: TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontStyle: FontStyle.italic),
                ),
              ),

            if (canUnassign)
              TextButton.icon(
                icon: const Icon(Icons.delete, color: Colors.red),
                label: const Text(
                  "Supprimer la course",
                  style: TextStyle(color: Colors.red),
                ),
                onPressed: () => unassignRide(context, ride),
              ),
          ],
        ),
      ),
    );
  }

  Widget _historyCard(DocumentSnapshot ride) {
    final data = ride.data() as Map<String, dynamic>;

    return Card(
      color: Colors.grey.shade100,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: ListTile(
        title: Text(data["passengerName"] ?? ""),
        subtitle: Text(
          "Date : ${data["pickupDateTimeText"] ?? ""}\nStatut : ${data["status"]}",
        ),
      ),
    );
  }
}
