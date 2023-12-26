import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CreateTournamentPage extends StatefulWidget {
  const CreateTournamentPage({super.key});

  @override
  CreateTournamentPageState createState() => CreateTournamentPageState();
}

class CreateTournamentPageState extends State<CreateTournamentPage> {
  final TextEditingController _tournamentNameController =
      TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _eventTypeController = TextEditingController();
  final TextEditingController _expirationDateController =
      TextEditingController();
  final List<String> _guestList = [];
  final List<DateTime> _selectedDates = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          "Créer un tournoi",
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.close,
              color: Colors.black,
            ),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                controller: _tournamentNameController,
                decoration: const InputDecoration(labelText: "Nom du tournoi"),
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _eventTypeController,
                decoration: const InputDecoration(labelText: "Type de tournoi"),
              ),
              const SizedBox(
                height: 16.0,
              ),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(labelText: "Lieu"),
              ),
              const SizedBox(height: 16.0),
              _buildGuestList(),
              const SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: () {
                  _addGuest(context);
                },
                child: const Text("Ajouter un invité"),
              ),
              const SizedBox(height: 16.0),
              _buildDateList(),
              const SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: () {
                  _showDateTimePickerDialog(context);
                },
                child: const Text("Ajouter un choix de date"),
              ),
              const SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: () {
                  _showExpirationDateTimePickerDialog(context);
                },
                child: Text(
                    "Date limite d'inscription:\n ${_expirationDateController.text}"),
              ),
              const SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: () {
                  // Traitement à effectuer lors de la soumission du formulaire
                  submitTournament();
                },
                child: const Text("Créer le tournoi"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuestList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Liste des invités"),
        const SizedBox(height: 8.0),
        Wrap(
          children: _guestList.map((guest) {
            return Chip(
              label: Text(guest),
              deleteIcon: const Icon(Icons.cancel),
              onDeleted: () {
                _removeGuest(guest);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  void _addGuest(BuildContext context) async {
    String? newGuest = await showDialog(
      context: context,
      builder: (BuildContext context) {
        String guest = '';
        return AlertDialog(
          title: const Text('Ajouter un invité'),
          content: TextField(
            onChanged: (value) {
              guest = value;
            },
            decoration: const InputDecoration(hintText: 'Email de l\'invité'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Annuler
              },
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, guest); // Ajouter
              },
              child: const Text('Ajouter'),
            ),
          ],
        );
      },
    );

    if (newGuest != null &&
        newGuest.isNotEmpty &&
        !_guestList.contains(newGuest) &&
        isValidEmail(newGuest)) {
      setState(() {
        _guestList.add(newGuest);
      });
    }
  }

  void _removeGuest(String guest) {
    setState(() {
      _guestList.remove(guest);
    });
  }

  Widget _buildDateList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Choix de dates"),
        const SizedBox(height: 8.0),
        Wrap(
          children: _selectedDates.map((dateStr) {
            return Chip(
              label: Text(DateFormat('dd/MM/yyyy HH:mm').format(dateStr)),
              deleteIcon: const Icon(Icons.cancel),
              onDeleted: () {
                _removeDate(dateStr);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  void _removeDate(DateTime date) {
    setState(() {
      _selectedDates.remove(date);
    });
  }

  Future<void> _showExpirationDateTimePickerDialog(BuildContext context) async {
    DateTime currentDate = DateTime.now();

    List<Object?> results = await Future.wait([
      showDatePicker(
        context: context,
        initialDate: currentDate,
        firstDate: currentDate,
        lastDate: DateTime(currentDate.year + 100),
        selectableDayPredicate: (DateTime date) {
          return true;
        },
      ),
    ]);

    DateTime? pickedDate = results[0] as DateTime?;

    if (pickedDate != null) {
      setState(() {
        _expirationDateController.text =
            "${pickedDate.day}/${pickedDate.month}/${pickedDate.year}";
      });
    }
  }

  // Fonction pour afficher le dialogue de sélection de dates
  Future<void> _showDateTimePickerDialog(BuildContext context) async {
    DateTime currentDate = DateTime.now();

    BuildContext dialogContext = context;

    // Sélection de la date
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: currentDate,
      lastDate: DateTime(currentDate.year + 100),
      selectableDayPredicate: (DateTime date) {
        return true;
      },
    );

    if (pickedDate != null) {
      // Sélection de l'heure
      // ignore: use_build_context_synchronously
      TimeOfDay? pickedTime = await showTimePicker(
        context: dialogContext,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null) {
        // Combinaison de la date et de l'heure sélectionnées
        DateTime selectedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        // Utilisez selectedDateTime selon vos besoins
        if (!_selectedDates.contains(selectedDateTime)) {
          setState(() {
            _selectedDates.add(selectedDateTime);
          });
        }
      }
    }
  }

  void _showErrorDialog(BuildContext context, String errorMessage) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Erreur"),
          content: Text(errorMessage),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Ferme la boîte de dialogue
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  void submitTournament() {
    String tournamentName = _tournamentNameController.text;
    String location = _locationController.text;
    String expirationDate = _expirationDateController.text;

    // should always be not null as the user is already connected from here
    String createdBy = (FirebaseAuth.instance.currentUser!.email)!;

    if (tournamentName.isEmpty ||
        location.isEmpty ||
        _selectedDates.isEmpty ||
        expirationDate.isEmpty ||
        _guestList.isEmpty) {
      _showErrorDialog(context,
          "Un des champs requis à la création du tournoi n'a pas été rempli. Veuillez le remplir avant de soumettre le tournoi");
      return;
    }

    // Get reference to tournament table from firebase
    DatabaseReference tournamentRef =
        FirebaseDatabase.instance.ref().child("tournois");

    // Get the key chosen from this table (should check its unicity)
    String key = '$tournamentName-${_locationController.text}';

    //At this point, we have not already participant list
    //(they have not confirmed yet their participation)
    Map<String, dynamic> tournamentData = {
      "createdBy": createdBy,
      "location": location,
      "sportEvent": _eventTypeController.text,
      "tournamentDate": {
        "suggestionDate": getSuggestionDate(),
        "expirationDate": _expirationDateController.text,
      },
    };

    // Enregistrez le tournoi dans la base de données en utilisant la clé composite
    tournamentRef.child(key).set(tournamentData).then((value) {
      // Tournoi enregistré avec succès
      // Vous pouvez ajouter d'autres actions ici si nécessaire
      if (kDebugMode) {
        print("Tournoi enregistré avec succès");
      }
      notifyRegisteredUser();
    }).catchError((error) {
      // Gestion des erreurs
      if (kDebugMode) {
        print("Erreur lors de l'enregistrement du tournoi : $error");
      }
    });
  }

  //TODO voir comment on peut notifier l'application des utilisateurs invités
  void notifyRegisteredUser() {}

  List<String> getSuggestionDate() {
    List<String> formattedDates = _selectedDates.map((dateTime) {
      return DateFormat("dd/MM/yyyy à HH:mm:ss").format(dateTime);
    }).toList();
    return formattedDates;
  }

  bool isValidEmail(String input) {
    final RegExp emailRegex =
        RegExp(r'^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$');
    return emailRegex.hasMatch(input);
  }
}

class AnimatedCreateTournamentPageRoute extends PageRouteBuilder {
  final Widget page;

  AnimatedCreateTournamentPageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 1.0);
            const end = Offset.zero;
            const curve = Curves.easeInOut;

            var tween =
                Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

            var offsetAnimation = animation.drive(tween);

            return SlideTransition(
              position: offsetAnimation,
              child: child,
            );
          },
        );
}
