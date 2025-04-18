import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AdresseAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode nextFocus;

  AdresseAutocompleteField({Key? key, required this.controller, required this.nextFocus}) : super(key: key);

  @override
  _AdresseAutocompleteFieldState createState() => _AdresseAutocompleteFieldState();
}

class _AdresseAutocompleteFieldState extends State<AdresseAutocompleteField> {
  final FocusNode _focusNode = FocusNode();
  OverlayEntry? _overlayEntry;
  List<String> _suggestions = [];
  bool _isLoading = false; // Pour indiquer le chargement (optionnel)

  // Flag pour savoir si une sélection vient d'être faite
  bool _justSelected = false;

  @override
  void initState() {
    super.initState();
    // Écoute les changements dans le texte
    widget.controller.addListener(_onTextChanged);
    // Écoute les changements de focus pour masquer l'overlay
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    // Important : retirer les listeners pour éviter les fuites mémoire
    widget.controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _removeOverlay(); // Assure que l'overlay est retiré
    super.dispose();
  }

  void _onTextChanged() {
    // Si le widget n'est plus dans l'arbre ou n'a pas le focus, ne rien faire
    if (!mounted || !_focusNode.hasFocus) return;

    // Appelle fetchSuggestions seulement si le texte a été modifié par l'utilisateur
    // (et non par la sélection)
    _fetchSuggestions(widget.controller.text);
  }

  void _onFocusChanged() {
    // Si le champ perd le focus, masquer l'overlay
    if (!mounted) return;
    if (!_focusNode.hasFocus) {
       // Petit délai pour permettre au onTap de la suggestion d'être traité avant de masquer
       Future.delayed(const Duration(milliseconds: 200), () {
         if (!_focusNode.hasFocus) { // Re-vérifier après le délai
             _removeOverlay();
         }
       });
    }
  }


  Future<void> _fetchSuggestions(String query) async {
    // Si une sélection vient d'être faite, ne pas relancer une recherche immédiatement.
    // Réinitialiser le flag et sortir.
    if (_justSelected) {
       setState(() {
           _justSelected = false; // Réinitialiser pour les prochaines frappes
       });
       return;
    }

    if (query.trim().isEmpty) {
      setState(() {
        _suggestions = [];
      });
      _removeOverlay();
      return;
    }

    setState(() {
      _isLoading = true; // Indiquer le début du chargement
    });

    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&addressdetails=1&limit=5');

    try {
      final response = await http.get(url, headers: {'User-Agent': 'YourFlutterAppName/1.0'}); // Soyez spécifique avec le User-Agent

      if (!mounted) return; // Vérifier si le widget est toujours là après l'appel réseau

      if (response.statusCode == 200) {
        List data = json.decode(utf8.decode(response.bodyBytes)); // Gérer l'encodage
        setState(() {
          _suggestions = data.map<String>((item) => item["display_name"]).toList();
          _isLoading = false;
        });
        // Afficher l'overlay seulement si le champ a toujours le focus et qu'il y a des suggestions
        if (_focusNode.hasFocus && _suggestions.isNotEmpty) {
          _showOverlay();
        } else {
          _removeOverlay(); // Masquer s'il n'y a pas de suggestion ou si focus perdu
        }
      } else {
         if (!mounted) return;
         setState(() {
           _isLoading = false;
           _suggestions = []; // Vider les suggestions en cas d'erreur
         });
         _removeOverlay();
         // Gérer l'erreur (ex: afficher un message)
         print('Nominatim request failed with status: ${response.statusCode}');
      }
    } catch (e) {
       if (!mounted) return;
       setState(() {
         _isLoading = false;
         _suggestions = [];
       });
       _removeOverlay();
       print('Error fetching suggestions: $e');
       // Gérer l'exception (ex: problème réseau)
    }
  }

  void _showOverlay() {
    _removeOverlay(); // Assure qu'un seul overlay est visible
    if (!mounted) return; // Ne pas construire si le widget est disposé

    final overlay = Overlay.of(context);
    // Trouver la RenderBox pour obtenir la position et la taille du TextField
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;
    final position = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: position.dx,
        top: position.dy + size.height + 5, // Positionner sous le TextField
        width: size.width, // Même largeur que le TextField
        child: Material(
          elevation: 4.0,
          borderRadius: BorderRadius.circular(8),
          child: Container(
             constraints: BoxConstraints(maxHeight: 200), // Hauteur max pour la liste
             decoration: BoxDecoration(
               color: Colors.white,
               borderRadius: BorderRadius.circular(8),
             ),
             child: ListView.builder(
               padding: EdgeInsets.zero,
               shrinkWrap: true, // S'adapte à la taille du contenu
               itemCount: _suggestions.length,
               itemBuilder: (context, index) {
                 return ListTile(
                   title: Text(_suggestions[index]),
                   onTap: () {
                     // 1. Marquer qu'une sélection a été faite
                     setState(() {
                        _justSelected = true;
                     });

                     // 2. Mettre à jour le texte du controller (ceci déclenchera _onTextChanged)
                     widget.controller.text = _suggestions[index];

                     // 3. Masquer l'overlay
                     _removeOverlay();

                     // 4. Retirer le focus du champ actuel pour masquer le clavier
                     _focusNode.unfocus();

                     // 5. Donner le focus au champ suivant (peut nécessiter un court délai si l'UI doit se stabiliser)
                     FocusScope.of(context).requestFocus(widget.nextFocus);
                   },
                 );
               },
             ),
          ),
        ),
      ),
    );

    // Insérer le nouvel overlay
    overlay.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      focusNode: _focusNode, // Important d'associer le FocusNode
      decoration: InputDecoration(
        hintText: "location_input".tr(), // Assurez-vous que easy_localization est configuré
        border: OutlineInputBorder(),
        // Optionnel: Afficher un indicateur de chargement
        suffixIcon: _isLoading
            ? Container(
                 width: 20, height: 20,
                 padding: const EdgeInsets.all(12.0),
                 child: CircularProgressIndicator(strokeWidth: 2))
            : null,
      ),
      // Vous pouvez ajouter d'autres propriétés ici (onSubmitted, textInputAction, etc.)
    );
  }
}