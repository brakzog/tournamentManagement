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
      body: Padding(
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
                // Traitement à effectuer lors de la soumission du formulaire
              },
              child: const Text("Créer le tournoi"),
            ),
          ],
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
            decoration: const InputDecoration(hintText: 'Nom de l\'invité'),
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

    if (newGuest != null && newGuest.isNotEmpty) {
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

  // Fonction pour afficher le dialogue de sélection de dates
  Future<void> _showDateTimePickerDialog(BuildContext context) async {
    DateTime currentDate = DateTime.now();

    BuildContext dialogContext = context;

    List<Object?> results = await Future.wait([
      showDatePicker(
        context: context,
        initialDate: currentDate,
        firstDate: currentDate,
        lastDate: DateTime(2101),
        selectableDayPredicate: (DateTime date) {
          return true;
        },
      ),
      showTimePicker(
        context: dialogContext,
        initialTime: TimeOfDay.now(),
      ),
    ]);

    DateTime? pickedDate = results[0] as DateTime?;
    TimeOfDay? pickedTime = results[1] as TimeOfDay?;

    if (pickedDate != null && pickedTime != null) {
      DateTime selectedDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );

      if (!_selectedDates.contains(selectedDateTime)) {
        setState(() {
          _selectedDates.add(selectedDateTime);
        });
      }
    }
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
