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

  logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  /// 📅 Select Date + Time (France Locale UI)
  selectDateTime() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      helpText: "Sélectionner la date de prise en charge",
      locale: const Locale('fr', 'FR'),
    );

    if (selectedDate == null) return;

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: "Sélectionner l’heure de prise en charge",
    );

    if (selectedTime == null) return;

    final dt = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    setState(() => pickupDateTime = dt);
  }

  /// 🚕 Assign Ride
  assignRide() {
    if (!formKey.currentState!.validate() ||
        selectedDriver == null ||
        pickupDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez remplir tous les champs obligatoires")),
      );
      return;
    }

    final frFormatted =
        DateFormat("dd/MM/yyyy HH:mm", "fr_FR").format(pickupDateTime!);

    FirebaseFirestore.instance.collection("rides").add({
      "assignedDriverId": selectedDriver,

      /// Date & Time
      "pickupDateTimeUtc": pickupDateTime,
      "pickupDateTimeText": frFormatted,

      /// Rider Info
      "passengerName": passenger.text.trim(),
      "passengerPhone": phone.text.trim(),

      /// Locations
      "pickupLocation": pickup.text.trim(),
      "dropLocation": drop.text.trim(),

      /// Flight & People
      "flightNumber": flight.text.trim(),
      "personsCount": persons.text.trim(),
      "bagsCount": bags.text.trim(),

      /// Optional Notes
      "otherNotes": others.text.trim(),

      "status": "assigné"
    });

    passenger.clear();
    phone.clear();
    pickup.clear();
    drop.clear();
    flight.clear();
    persons.clear();
    bags.clear();
    others.clear();

    setState(() {
      selectedDriver = null;
      pickupDateTime = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Course assignée avec succès")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Panneau Dispatcheur"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Se déconnecter",
            onPressed: () => logout(context),
          )
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
                const Text(
                  "Créer une nouvelle course",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 25),

                /// 1️⃣ DATE TIME
                InkWell(
                  onTap: selectDateTime,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: "Date et heure de prise en charge",
                      border: UnderlineInputBorder(),
                    ),
                    child: Text(
                      pickupDateTime == null
                          ? "Sélectionner la date et l’heure"
                          : DateFormat("dd/MM/yyyy HH:mm", "fr_FR")
                              .format(pickupDateTime!),
                      style: TextStyle(
                        color: pickupDateTime == null
                            ? Colors.grey
                            : Colors.black,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                /// 2️⃣ CLIENT NAME
                TextFormField(
                  controller: passenger,
                  decoration: const InputDecoration(
                      labelText: "Nom du client"),
                  validator: (v) => v!.isEmpty ? "Champ obligatoire" : null,
                ),

                /// 3️⃣ PHONE
                TextFormField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                      labelText: "Téléphone du client"),
                  validator: (v) => v!.isEmpty ? "Champ obligatoire" : null,
                ),

                /// 4️⃣ PICKUP
                TextFormField(
                  controller: pickup,
                  decoration:
                      const InputDecoration(labelText: "Adresse départ"),
                  validator: (v) => v!.isEmpty ? "Champ obligatoire" : null,
                ),

                /// 5️⃣ DROP
                TextFormField(
                  controller: drop,
                  decoration:
                      const InputDecoration(labelText: "Adresse destination"),
                  validator: (v) => v!.isEmpty ? "Champ obligatoire" : null,
                ),

                /// 6️⃣ FLIGHT
                TextFormField(
                  controller: flight,
                  decoration:
                      const InputDecoration(labelText: "Numéro de vol"),
                  validator: (v) => v!.isEmpty ? "Champ obligatoire" : null,
                ),

                /// 7️⃣ PERSONS
                TextFormField(
                  controller: persons,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: "Nombre de personnes"),
                  validator: (v) => v!.isEmpty ? "Champ obligatoire" : null,
                ),

                /// 8️⃣ BAGS
                TextFormField(
                  controller: bags,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: "Nombre de bagages"),
                  validator: (v) => v!.isEmpty ? "Champ obligatoire" : null,
                ),

                /// 9️⃣ NOTES (optional)
                TextFormField(
                  controller: others,
                  decoration: const InputDecoration(labelText: "Autres"),
                ),

                const SizedBox(height: 25),

                /// DRIVER SELECT
                StreamBuilder(
                  stream: FirebaseFirestore.instance
                      .collection("users")
                      .where("role", isEqualTo: "driver")
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Text("Chargement des chauffeurs...");
                    }

                    var drivers = snapshot.data!.docs;

                    return DropdownButtonFormField(
                      value: selectedDriver,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: "Sélectionner un chauffeur",
                      ),
                      items: drivers.map((d) {
                        return DropdownMenuItem(
                          value: d.id,
                          child: Text(d["name"]),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => selectedDriver = value);
                      },
                      validator: (value) =>
                          value == null ? "Sélection obligatoire" : null,
                    );
                  },
                ),

                const SizedBox(height: 25),

                Center(
                  child: ElevatedButton(
                    onPressed: assignRide,
                    child: const Text("Assigner la course"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
