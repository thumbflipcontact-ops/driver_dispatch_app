import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AssignedRidesPage extends StatelessWidget {
  const AssignedRidesPage({Key? key}) : super(key: key);

  final String statusAssigned = "assigné";
  final String statusStarted = "démarré";
  final String statusCompleted = "terminé";
  final String statusUnassigned = "non assigné";

  // ✅ helper: selectable + copyable text
  Widget _sText(String text, {TextStyle? style}) {
    return SelectableText(
      text,
      style: style,
      toolbarOptions: const ToolbarOptions(copy: true, selectAll: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Courses assignées")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection("rides").snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final List<QueryDocumentSnapshot> rides =
              snapshot.data!.docs.where((d) => d.exists).toList();

          if (rides.isEmpty) {
            return const Center(child: Text("Aucune course"));
          }

          // SAME SORTING LOGIC (recent -> old)
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

              final String status = (data["status"] ?? "").toString();
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
                      _sText(
                        (data["passengerName"] ?? "Client").toString(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),

                      _sText("Téléphone : ${data["passengerPhone"] ?? "-"}"),
                      _sText("Heure : ${data["pickupDateTimeText"] ?? "-"}"),
                      _sText("Adresse départ : ${data["pickupLocation"] ?? "-"}"),
                      _sText(
                          "Adresse destination : ${data["dropLocation"] ?? "-"}"),
                      _sText("Numéro de vol : ${data["flightNumber"] ?? "-"}"),
                      _sText(
                          "Nombre de personnes : ${data["personsCount"] ?? "-"}"),
                      _sText(
                          "Nombre de bagages : ${data["bagsCount"] ?? "-"}"),
                      _sText("Autres notes : ${data["otherNotes"] ?? "-"}"),

                      const SizedBox(height: 6),

                      _sText("Statut : $status"),
                      _driverNameWidget(driverId),

                      const SizedBox(height: 8),

                      Align(
                        alignment: Alignment.centerRight,
                        child: PopupMenuButton<String>(
                          itemBuilder: (context) {
                            final items = <PopupMenuEntry<String>>[];

                            items.add(const PopupMenuItem(
                              value: "edit",
                              child: Text("Modifier la course"),
                            ));

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

                            items.add(const PopupMenuItem(
                              value: "delete",
                              child: Text("Supprimer la course"),
                            ));

                            return items;
                          },
                          onSelected: (value) async {
                            if (value == "edit") {
                              _showEditRideDialog(context, ride.id, data);
                            }

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
  // DRIVER PICKER
  // ─────────────────────────────
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
                  title: SelectableText(
                    name.toString(),
                    toolbarOptions:
                        const ToolbarOptions(copy: true, selectAll: true),
                  ),
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

  // ─────────────────────────────
  // DRIVER NAME RESOLUTION
  // ─────────────────────────────
  Widget _driverNameWidget(String? driverId) {
    if (driverId == null) {
      return _sText("Chauffeur : Non assigné");
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection("users").doc(driverId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _sText("Chauffeur : Inconnu");
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final name = data["name"] ?? "Sans nom";

        return _sText("Chauffeur : $name");
      },
    );
  }
}
