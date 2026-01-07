import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

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

  String? selectedDriver;
  final formKey = GlobalKey<FormState>();

  DateTime? pickupDateTime;

  final searchController = TextEditingController();
  bool sortAscending = true;

  logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  Stream<QuerySnapshot> driverStream() {
    return FirebaseFirestore.instance
        .collection("users")
        .where("role", isEqualTo: "driver")
        .snapshots();
  }

  selectDateTime() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      locale: const Locale("fr", "FR"),
    );

    if (d == null) return;

    final t = await showTimePicker(
        context: context, initialTime: TimeOfDay.now());

    if (t == null) return;

    setState(() {
      pickupDateTime =
          DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  assignRide() async {
    if (!formKey.currentState!.validate() ||
        selectedDriver == null ||
        pickupDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez remplir tout")),
      );
      return;
    }

    await FirebaseFirestore.instance.collection("rides").add({
      "assignedDriverId": selectedDriver,
      "pickupDateTimeUtc": pickupDateTime,
      "pickupDateTimeText":
          DateFormat("dd/MM/yyyy HH:mm", "fr_FR").format(pickupDateTime!),
      "passengerName": passenger.text.trim(),
      "passengerPhone": phone.text.trim(),
      "pickupLocation": pickup.text.trim(),
      "dropLocation": drop.text.trim(),
      "flightNumber": flight.text.trim(),
      "personsCount": persons.text.trim(),
      "bagsCount": bags.text.trim(),
      "otherNotes": others.text.trim(),
      "status": "assigné"
    });

    selectedDriver = null;
    pickupDateTime = null;
    passenger.clear();
    phone.clear();
    pickup.clear();
    drop.clear();
    flight.clear();
    persons.clear();
    bags.clear();
    others.clear();

    setState(() {});

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Assigné")));
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
          IconButton(
              onPressed: logout, icon: const Icon(Icons.logout))
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                /// ---------------- CREATE RIDE ----------------
                InkWell(
                  onTap: selectDateTime,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                        labelText: "Date & Heure"),
                    child: Text(
                      pickupDateTime == null
                          ? "Sélectionner"
                          : DateFormat("dd/MM/yyyy HH:mm", "fr_FR")
                              .format(pickupDateTime!),
                    ),
                  ),
                ),

                TextFormField(
                  controller: passenger,
                  validator: (v) => v!.isEmpty ? "obligatoire" : null,
                  decoration:
                      const InputDecoration(labelText: "Client"),
                ),

                TextFormField(
                  controller: phone,
                  validator: (v) => v!.isEmpty ? "obligatoire" : null,
                  decoration: const InputDecoration(labelText: "Téléphone"),
                ),

                const SizedBox(height: 10),

                /// ---------------- DRIVER DROPDOWN ----------------
                StreamBuilder<QuerySnapshot>(
                  stream: driverStream(),
                  builder: (context, s) {
                    if (!s.hasData) return const Text("Chargement...");
                    final drivers = s.data!.docs;
                    if (drivers.isEmpty) return const Text("Aucun chauffeur");

                    return DropdownButtonFormField(
                      value: selectedDriver,
                      decoration: const InputDecoration(
                          labelText: "Sélectionner un chauffeur"),
                      items: drivers.map((d) {
                        final name = (d["name"] ?? "Sans nom").toString();
                        return DropdownMenuItem(
                            value: d.id, child: Text(name));
                      }).toList(),
                      onChanged: (v) => setState(() {
                        selectedDriver = v;
                      }),
                      validator: (v) =>
                          v == null ? "Obligatoire" : null,
                    );
                  },
                ),

                const SizedBox(height: 20),

                Center(
                  child: ElevatedButton(
                      onPressed: assignRide,
                      child: const Text("Assigner la course")),
                ),

                const SizedBox(height: 30),

                /// ---------------- DRIVER MANAGEMENT ----------------
                const Text("Gérer les chauffeurs",
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),

                TextField(
                  controller: searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      labelText: "Rechercher"),
                ),

                const SizedBox(height: 10),

                StreamBuilder<QuerySnapshot>(
                  stream: driverStream(),
                  builder: (context, s) {
                    if (!s.hasData) return const CircularProgressIndicator();

                    List docs = s.data!.docs;

                    /// filter
                    if (searchController.text.isNotEmpty) {
                      final key =
                          searchController.text.toLowerCase().trim();
                      docs = docs.where((d) {
                        final name =
                            (d["name"] ?? "").toString().toLowerCase();
                        return name.contains(key);
                      }).toList();
                    }

                    if (docs.isEmpty) {
                      return const Text("Aucun chauffeur trouvé");
                    }

                    /// THIS IS THE FIX:
                    /// Column instead of ListView (no grey ever)
                    return Column(
                      children: docs.map<Widget>((d) {
                        final name =
                            (d["name"] ?? "Sans nom").toString();

                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.person),
                            title: Text(name),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Colors.red),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text("Supprimer ?"),
                                    content:
                                        Text("Supprimer $name ?"),
                                    actions: [
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text("Annuler")),
                                      TextButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                            deleteDriver(d.id);
                                          },
                                          child:
                                              const Text("Supprimer")),
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
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
