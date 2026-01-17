import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

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
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          DateTime now = DateTime.now();
          List<QueryDocumentSnapshot> rides = snapshot.data!.docs.toList();

          // ✅ UPCOMING = assigné + date >= now
          if (status == "assigné") {
            rides = rides.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final Timestamp? ts = data["pickupDateTimeUtc"];
              if (ts == null) return false;

              final date = ts.toDate();
              return date.isAfter(now) || date.isAtSameMomentAs(now);
            }).toList();
          }

          if (rides.isEmpty) {
            return const Center(child: Text("Aucune course"));
          }

          // SAME SORTING
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

                      Text("Statut : ${data["status"] ?? "-"}"),
                      _driverNameWidget(driverId),

                      const SizedBox(height: 8),

                      Align(
                        alignment: Alignment.centerRight,
                        child: PopupMenuButton<String>(
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: "edit",
                              child: Text("Modifier"),
                            ),
                            PopupMenuItem(
                              value: "delete",
                              child: Text("Supprimer"),
                            ),
                          ],
                          onSelected: (val) async {
                            if (val == "delete") {
                              await FirebaseFirestore.instance
                                  .collection("rides")
                                  .doc(ride.id)
                                  .delete();
                            }

                            if (val == "edit") {
                              _showEditRideDialog(context, ride.id, data);
                            }
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

  // ─────────────────────────────
  // EDIT RIDE DIALOG (ALL FIELDS)
  // ─────────────────────────────
  void _showEditRideDialog(
    BuildContext context,
    String rideId,
    Map<String, dynamic> data,
  ) {
    final passenger = TextEditingController(text: data["passengerName"] ?? "");
    final phone = TextEditingController(text: data["passengerPhone"] ?? "");
    final pickup = TextEditingController(text: data["pickupLocation"] ?? "");
    final drop = TextEditingController(text: data["dropLocation"] ?? "");
    final flight = TextEditingController(text: data["flightNumber"] ?? "");
    final persons = TextEditingController(text: data["personsCount"] ?? "");
    final bags = TextEditingController(text: data["bagsCount"] ?? "");
    final others = TextEditingController(text: data["otherNotes"] ?? "");

    DateTime? pickedDateTime;
    final Timestamp? ts = data["pickupDateTimeUtc"];
    if (ts != null) pickedDateTime = ts.toDate();

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            Future<void> pickDateTime() async {
              final d = await showDatePicker(
                context: context,
                initialDate: pickedDateTime ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (d == null) return;

              final t = await showTimePicker(
                context: context,
                initialTime: pickedDateTime == null
                    ? TimeOfDay.now()
                    : TimeOfDay.fromDateTime(pickedDateTime!),
              );
              if (t == null) return;

              setLocal(() {
                pickedDateTime =
                    DateTime(d.year, d.month, d.day, t.hour, t.minute);
              });
            }

            return AlertDialog(
              title: const Text("Modifier la course"),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    InkWell(
                      onTap: pickDateTime,
                      child: InputDecorator(
                        decoration:
                            const InputDecoration(labelText: "Date & Heure"),
                        child: Text(
                          pickedDateTime == null
                              ? "Sélectionner"
                              : DateFormat("dd/MM/yyyy HH:mm")
                                  .format(pickedDateTime!),
                        ),
                      ),
                    ),
                    TextField(
                      controller: passenger,
                      decoration: const InputDecoration(labelText: "Client"),
                    ),
                    TextField(
                      controller: phone,
                      decoration: const InputDecoration(labelText: "Téléphone"),
                    ),
                    TextField(
                      controller: pickup,
                      decoration:
                          const InputDecoration(labelText: "Adresse départ"),
                    ),
                    TextField(
                      controller: drop,
                      decoration: const InputDecoration(
                          labelText: "Adresse destination"),
                    ),
                    TextField(
                      controller: flight,
                      decoration:
                          const InputDecoration(labelText: "Numéro de vol"),
                    ),
                    TextField(
                      controller: persons,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: "Nombre de personnes"),
                    ),
                    TextField(
                      controller: bags,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: "Nombre de bagages"),
                    ),
                    TextField(
                      controller: others,
                      decoration: const InputDecoration(labelText: "Autres"),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Annuler"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await FirebaseFirestore.instance
                        .collection("rides")
                        .doc(rideId)
                        .update({
                      "passengerName": passenger.text.trim(),
                      "passengerPhone": phone.text.trim(),
                      "pickupLocation": pickup.text.trim(),
                      "dropLocation": drop.text.trim(),
                      "flightNumber": flight.text.trim(),
                      "personsCount": persons.text.trim(),
                      "bagsCount": bags.text.trim(),
                      "otherNotes": others.text.trim(),
                      if (pickedDateTime != null)
                        "pickupDateTimeUtc": pickedDateTime,
                      if (pickedDateTime != null)
                        "pickupDateTimeText": DateFormat("dd/MM/yyyy HH:mm")
                            .format(pickedDateTime!),
                    });

                    Navigator.pop(context);
                  },
                  child: const Text("Enregistrer"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ─────────────────────────────
  // DRIVER NAME RESOLUTION
  // ─────────────────────────────
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
