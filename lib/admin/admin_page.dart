import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'assigned_rides_page.dart';
import 'rides_by_status_page.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({Key? key}) : super(key: key);

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final passenger = TextEditingController();
  final phone = TextEditingController();
  final pickup = TextEditingController();
  final drop = TextEditingController();
  final flight = TextEditingController();
  final persons = TextEditingController();
  final bags = TextEditingController();
  final others = TextEditingController();

  // ✅ NEW
  final tarif = TextEditingController();

  final searchController = TextEditingController();

  String? selectedDriver;
  DateTime? pickupDateTime;

  final formKey = GlobalKey<FormState>();

  Widget _sText(String text, {TextStyle? style}) {
    return SelectableText(
      text,
      style: style,
      toolbarOptions: const ToolbarOptions(copy: true, selectAll: true),
    );
  }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  Stream<QuerySnapshot> driverStream() {
    return FirebaseFirestore.instance
        .collection("users")
        .where("role", isEqualTo: "driver")
        .snapshots();
  }

  Future<void> selectDateTime() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (d == null) return;

    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (t == null) return;

    setState(() {
      pickupDateTime = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  Future<void> assignRide() async {
    if (!formKey.currentState!.validate() ||
        selectedDriver == null ||
        pickupDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez remplir tous les champs")),
      );
      return;
    }

    await FirebaseFirestore.instance.collection("rides").add({
      "assignedDriverId": selectedDriver,
      "assignedAt": FieldValue.serverTimestamp(),
      "pickupDateTimeUtc": pickupDateTime,
      "pickupDateTimeText":
          DateFormat("dd/MM/yyyy HH:mm").format(pickupDateTime!),
      "passengerName": passenger.text.trim(),
      "passengerPhone": phone.text.trim(),
      "pickupLocation": pickup.text.trim(),
      "dropLocation": drop.text.trim(),
      "flightNumber": flight.text.trim(),
      "personsCount": persons.text.trim(),
      "bagsCount": bags.text.trim(),
      "otherNotes": others.text.trim(),

      // ✅ NEW FIELD
      "tarif": tarif.text.trim(),

      "status": "assigné",
    });

    passenger.clear();
    phone.clear();
    pickup.clear();
    drop.clear();
    flight.clear();
    persons.clear();
    bags.clear();
    others.clear();
    tarif.clear(); // ✅ NEW
    selectedDriver = null;
    pickupDateTime = null;

    setState(() {});
  }

  Future<void> deleteDriver(String id) async {
    await FirebaseFirestore.instance.collection("users").doc(id).delete();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Chauffeur supprimé")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Panneau Dispatcheur"),
        actions: [
          IconButton(onPressed: logout, icon: const Icon(Icons.logout))
        ],
      ),
      bottomNavigationBar: _footer(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: selectDateTime,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: "Date & Heure"),
                    child: Text(
                      pickupDateTime == null
                          ? "Sélectionner"
                          : DateFormat("dd/MM/yyyy HH:mm")
                              .format(pickupDateTime!),
                    ),
                  ),
                ),
                TextFormField(
                  controller: passenger,
                  validator: (v) => v!.isEmpty ? "Obligatoire" : null,
                  decoration: const InputDecoration(labelText: "Client"),
                ),
                TextFormField(
                  controller: phone,
                  validator: (v) => v!.isEmpty ? "Obligatoire" : null,
                  decoration: const InputDecoration(labelText: "Téléphone"),
                ),
                TextFormField(
                  controller: pickup,
                  validator: (v) => v!.isEmpty ? "Obligatoire" : null,
                  decoration:
                      const InputDecoration(labelText: "Adresse départ"),
                ),
                TextFormField(
                  controller: drop,
                  validator: (v) => v!.isEmpty ? "Obligatoire" : null,
                  decoration:
                      const InputDecoration(labelText: "Adresse destination"),
                ),
                TextFormField(
                  controller: flight,
                  decoration: const InputDecoration(labelText: "Numéro de vol"),
                ),
                TextFormField(
                  controller: persons,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: "Nombre de personnes"),
                ),
                TextFormField(
                  controller: bags,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: "Nombre de bagages"),
                ),

                // ✅ NEW TARIF FIELD
                TextFormField(
                  controller: tarif,
                  keyboardType: TextInputType.text,
                  decoration: const InputDecoration(labelText: "Tarif"),
                ),

                TextFormField(
                  controller: others,
                  decoration: const InputDecoration(labelText: "Autres notes"),
                ),
                const SizedBox(height: 10),
                StreamBuilder<QuerySnapshot>(
                  stream: driverStream(),
                  builder: (context, s) {
                    if (!s.hasData) {
                      return const CircularProgressIndicator();
                    }

                    final drivers = s.data!.docs;
                    if (drivers.isEmpty) {
                      return const Text("Aucun chauffeur");
                    }

                    return DropdownButtonFormField(
                      value: selectedDriver,
                      decoration: const InputDecoration(
                          labelText: "Sélectionner un chauffeur"),
                      items: drivers.map((d) {
                        return DropdownMenuItem(
                          value: d.id,
                          child: Text(d["name"] ?? "Sans nom"),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => selectedDriver = v),
                      validator: (v) => v == null ? "Obligatoire" : null,
                    );
                  },
                ),
                const SizedBox(height: 20),
                Center(
                  child: ElevatedButton(
                    onPressed: assignRide,
                    child: const Text("Assigner la course"),
                  ),
                ),
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AssignedRidesPage(),
                        ),
                      );
                    },
                    child: const Text("Voir les courses assignées"),
                  ),
                ),
                const SizedBox(height: 30),
                const Text(
                  "Gérer les chauffeurs",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: "Rechercher",
                  ),
                ),
                const SizedBox(height: 10),
                StreamBuilder<QuerySnapshot>(
                  stream: driverStream(),
                  builder: (context, s) {
                    if (!s.hasData) {
                      return const CircularProgressIndicator();
                    }

                    List docs = s.data!.docs;

                    if (searchController.text.isNotEmpty) {
                      final key = searchController.text.toLowerCase().trim();
                      docs = docs.where((d) {
                        final name =
                            (d["name"] ?? "").toString().toLowerCase();
                        return name.contains(key);
                      }).toList();
                    }

                    if (docs.isEmpty) {
                      return const Text("Aucun chauffeur trouvé");
                    }

                    return Column(
                      children: docs.map<Widget>((d) {
                        final name = d["name"] ?? "Sans nom";

                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.person),
                            title: _sText(name.toString()),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text("Supprimer ?"),
                                    content:
                                        Text("Supprimer le chauffeur $name ?"),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context),
                                        child: const Text("Annuler"),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          deleteDriver(d.id);
                                        },
                                        child: const Text("Supprimer"),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _footer() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            blurRadius: 6,
            color: Colors.black.withOpacity(0.15),
          )
        ],
      ),
      child: Row(
        children: [
          _footerItem("À venir", "assigné", Colors.blue),
          _footerItem("En cours", "démarré", Colors.orange),
          _footerItem("Terminées", "terminé", Colors.green),
        ],
      ),
    );
  }

  Widget _footerItem(String label, String status, Color color) {
    return Expanded(
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RidesByStatusPage(
                status: status,
                title: label,
                color: color,
              ),
            ),
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _sText(label,
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("rides")
                  .where("status", isEqualTo: status)
                  .snapshots(),
              builder: (context, s) {
                if (!s.hasData) return const Text("-");

                DateTime now = DateTime.now();
                var docs = s.data!.docs;

                if (status == "assigné") {
                  docs = docs.where((d) {
                    final ts = d["pickupDateTimeUtc"];
                    if (ts == null) return false;
                    final date = ts.toDate();
                    return date.isAfter(now) || date.isAtSameMomentAs(now);
                  }).toList();
                }

                return _sText(
                  docs.length.toString(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
