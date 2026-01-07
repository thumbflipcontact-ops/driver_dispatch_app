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

  /// Search + Sorting
  final TextEditingController searchController = TextEditingController();
  bool sortAscending = true;

  logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  /// 📅 Select Date + Time
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
      "pickupDateTimeUtc": pickupDateTime,
      "pickupDateTimeText": frFormatted,
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

  /// ❌ Delete Driver
  Future<void> deleteDriver(String driverId) async {
    try {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(driverId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Chauffeur supprimé avec succès")),
      );

      if (selectedDriver == driverId) {
        setState(() => selectedDriver = null);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur suppression chauffeur: $e")),
      );
    }
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

                /// DATE TIME SELECTOR
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

                TextFormField(
                  controller: passenger,
                  decoration: const InputDecoration(labelText: "Nom du client"),
                  validator: (v) => v!.isEmpty ? "Champ obligatoire" : null,
                ),

                TextFormField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration:
                      const InputDecoration(labelText: "Téléphone du client"),
                  validator: (v) => v!.isEmpty ? "Champ obligatoire" : null,
                ),

                TextFormField(
                  controller: pickup,
                  decoration:
                      const InputDecoration(labelText: "Adresse départ"),
                  validator: (v) => v!.isEmpty ? "Champ obligatoire" : null,
                ),

                TextFormField(
                  controller: drop,
                  decoration:
                      const InputDecoration(labelText: "Adresse destination"),
                  validator: (v) => v!.isEmpty ? "Champ obligatoire" : null,
                ),

                TextFormField(
                  controller: flight,
                  decoration:
                      const InputDecoration(labelText: "Numéro de vol"),
                  validator: (v) => v!.isEmpty ? "Champ obligatoire" : null,
                ),

                TextFormField(
                  controller: persons,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: "Nombre de personnes"),
                  validator: (v) => v!.isEmpty ? "Champ obligatoire" : null,
                ),

                TextFormField(
                  controller: bags,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: "Nombre de bagages"),
                  validator: (v) => v!.isEmpty ? "Champ obligatoire" : null,
                ),

                TextFormField(
                  controller: others,
                  decoration: const InputDecoration(labelText: "Autres"),
                ),

                const SizedBox(height: 25),

                /// DRIVER DROPDOWN
                StreamBuilder<QuerySnapshot>(
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
                          child: Text(d["name"] ?? "Sans nom"),
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

                const SizedBox(height: 40),

                /// ================================
                /// 👤 DRIVER MANAGEMENT SECTION
                /// ================================
                const Text(
                  "Gérer les chauffeurs",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 10),

                /// 🔍 SEARCH BAR
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    labelText: "Rechercher un chauffeur",
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) => setState(() {}),
                ),

                const SizedBox(height: 10),

                /// SORT BUTTON
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(sortAscending ? "Tri: A → Z" : "Tri: Z → A"),
                    IconButton(
                      icon: Icon(
                        sortAscending
                            ? Icons.arrow_downward
                            : Icons.arrow_upward,
                      ),
                      onPressed: () {
                        setState(() {
                          sortAscending = !sortAscending;
                        });
                      },
                    ),
                  ],
                ),

                /// DRIVER LIST
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection("users")
                      .where("role", isEqualTo: "driver")
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData ||
                        snapshot.data!.docs.isEmpty) {
                      return const Text("Aucun chauffeur trouvé");
                    }

                    /// Convert docs to mutable list
                    List<QueryDocumentSnapshot> drivers =
                        snapshot.data!.docs.toList();

                    /// APPLY SEARCH FILTER
                    if (searchController.text.isNotEmpty) {
                      final keyword =
                          searchController.text.toLowerCase().trim();
                      drivers = drivers.where((d) {
                        final name =
                            (d["name"] ?? "").toString().toLowerCase();
                        final email =
                            (d["email"] ?? "").toString().toLowerCase();
                        return name.contains(keyword) ||
                            email.contains(keyword);
                      }).toList();
                    }

                    /// APPLY SORTING
                    drivers.sort((a, b) {
                      final nameA = (a["name"] ?? "").toString();
                      final nameB = (b["name"] ?? "").toString();
                      return sortAscending
                          ? nameA.compareTo(nameB)
                          : nameB.compareTo(nameA);
                    });

                    if (drivers.isEmpty) {
                      return const Text("Aucun résultat");
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: drivers.length,
                      itemBuilder: (context, index) {
                        final d = drivers[index];

                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.person),
                            title: Text(d["name"] ?? "Sans nom"),
                            subtitle: Text(d["email"] ?? ""),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Colors.red),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text(
                                        "Supprimer le chauffeur ?"),
                                    content: Text(
                                        "Êtes-vous sûr de vouloir supprimer ${d["name"] ?? "ce chauffeur"} ?"),
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
                      },
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
}
