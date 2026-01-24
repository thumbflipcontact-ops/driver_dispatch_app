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

  /// ✅ Safely resolve pickup date for sorting (new + old rides)
  DateTime? _getPickupDateTime(Map<String, dynamic> data) {
    final raw = data["pickupDateTimeUtc"];

    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;

    final text = data["pickupDateTimeText"];
    if (text is String && text.isNotEmpty) {
      try {
        return DateFormat("dd/MM/yyyy HH:mm").parse(text);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  String _rideCopyBlock(Map<String, dynamic> data, String driverLine) {
    return "Client : ${data["passengerName"] ?? "-"}\n"
        "Téléphone : ${data["passengerPhone"] ?? "-"}\n"
        "Heure : ${data["pickupDateTimeText"] ?? "-"}\n"
        "Adresse départ : ${data["pickupLocation"] ?? "-"}\n"
        "Adresse destination : ${data["dropLocation"] ?? "-"}\n"
        "Numéro de vol : ${data["flightNumber"] ?? "-"}\n"
        "Nombre de personnes : ${data["personsCount"] ?? "-"}\n"
        "Nombre de bagages : ${data["bagsCount"] ?? "-"}\n"
        "Tarif : ${data["tarif"] ?? "-"}\n"
        "Autres notes : ${data["otherNotes"] ?? "-"}\n"
        "Statut : ${data["status"] ?? "-"}\n"
        "$driverLine";
  }

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
              final DateTime? dt = _getPickupDateTime(data);
              if (dt == null) return false;
              return dt.isAfter(now) || dt.isAtSameMomentAs(now);
            }).toList();
          }

          if (rides.isEmpty) {
            return const Center(child: Text("Aucune course"));
          }

          /// ✅ NEW SORT: pickup datetime DESC (latest first)
          rides.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;

            final aTime = _getPickupDateTime(aData);
            final bTime = _getPickupDateTime(bData);

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
                      if (driverId == null)
                        SelectableText(
                          _rideCopyBlock(data, "Chauffeur : Non assigné"),
                          toolbarOptions: const ToolbarOptions(
                            copy: true,
                            selectAll: true,
                          ),
                        )
                      else
                        StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection("users")
                              .doc(driverId)
                              .snapshots(),
                          builder: (context, snap) {
                            String driverLine = "Chauffeur : Inconnu";
                            if (snap.hasData && snap.data!.exists) {
                              final d =
                                  snap.data!.data() as Map<String, dynamic>;
                              driverLine =
                                  "Chauffeur : ${d["name"] ?? "Sans nom"}";
                            }

                            return SelectableText(
                              _rideCopyBlock(data, driverLine),
                              toolbarOptions: const ToolbarOptions(
                                copy: true,
                                selectAll: true,
                              ),
                            );
                          },
                        ),

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
  // EDIT RIDE DIALOG (ALL FIELDS + TARIF)
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

    // ✅ NEW
    final tarif = TextEditingController(text: data["tarif"] ?? "");

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

                    // ✅ TARIF EDIT
                    TextField(
                      controller: tarif,
                      decoration: const InputDecoration(labelText: "Tarif"),
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

                      // ✅ NEW
                      "tarif": tarif.text.trim(),

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
}
