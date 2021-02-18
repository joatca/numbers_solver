/*
This file is part of Numbers Solver - solve the Numbers game used in several
long-running European game shows

Copyright (C) 2021 Fraser McCrossan

Numbers Solver is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:more/iterable.dart';

import 'game_classes.dart';

// encapsulates all of the non-widget state for the main page
class GameState {
  // maximum length of the target number, used for the target textfield
  static const maxTargetLength = 3;
  // maximum length of the source numbers, used for the source textfields in scary mode
  static const maxSourceLength = 3;
  // maximum number of solutions to store
  static const maxSolutions = 50; // plenty of options
  // number of sources required before allowing a solve
  static const numSourcesRequired = 6;

  // characters to use as labels
  static final int _firstLabelCode = 'A'.codeUnitAt(0);
  // labels start at zero; the source numbers first and then intermediates, so we want _numSourcesRequired of the first then the
  // same number of the second
  static final List<String> _labelLookup =
      Iterable.generate(numSourcesRequired * 2, (i) => i + _firstLabelCode).map((code) => String.fromCharCode(code)).toList();

  // list to help construct _sourcesAllowed
  static final List<int> _one2ten = Iterable.generate(10, (i) => i + 1).toList();
  // how many of each source number are allowed
  static final List<int> sourcesAllowed = _one2ten + _one2ten + [25, 50, 75, 100];

  // used to attempt to dismiss the keyboard once we start solving, and to set the initial target number from saved prefs
  TextEditingController _targetTextController = TextEditingController();
  TextEditingController get targetTextController => _targetTextController;
  // used to set source numbers from saved prefs
  List<TextEditingController> _sourceControllers;
  List<TextEditingController> get sourceControllers => _sourceControllers;

  // regular or scary mode?
  bool _scaryMode = false;
  bool get scaryMode => _scaryMode;
  // the actual target number
  var _targetNumber = 0;
  int get targetNumber => _targetNumber;
  void set targetNumber(int newTarget) {
    _targetNumber = newTarget;
    _saveValues();
  }
  // which sources are currently selected?
  List<bool> _sourcesSelected = List<bool>.filled(sourcesAllowed.length, false);
  List<bool> get sourcesSelected => _sourcesSelected;
  // actual numbers - set by the chips as well as manually in scary mode
  List<int> _sourceNumbers = List<int>.filled(numSourcesRequired, 0);
  List<int> get sourceNumbers => _sourceNumbers;

  GameState() {
    _sourceControllers = _sourceNumbers.map((s) => TextEditingController()).toList(); // generate enough of them on the fly
  }

  // should the UI allow the puzzle to be cleared?
  bool clearable() => _countSelected() > 0 || _targetNumber > 0;
  
  void load(Function afterLoad) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final String sources = prefs.getString('sources');
    _targetNumber = prefs.getInt('target') ?? 0;
    if (_targetNumber > 0) {
      // only try to set the target field if it's > 0, otherwise we can leave it blank
      _targetTextController.text = _targetNumber.toString();
    }
    if (sources != null) {
      // values are the source numbers comma-separated
      try {
        final List<int> nums = sources.split(',').map((s) => int.parse(s)).toList();
        nums.indexed().forEach((each) {
          _setSourceNumber(each.index, each.value);
        });
        if (!_sourceNumbers.every((sn) => sn == 0 || sourcesAllowed.any((sa) => sn == sa))) {
          _scaryMode = true; // we found some numbers outside regular numbers
        } else {
          _setIndexesFromNumbers();
        }
        afterLoad();
      } on Exception catch (e) {
        // probably some parsing error, we don't care, just fail to load
        print("exception: $e");
      }
    }
  }

  // save the current game state to shared preferences
  void _saveValues() async {
    if (!_scaryMode) {
      _setNumbersFromIndexes();
    }
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('sources', _sourceNumbers.map((n) => n.toString()).join(','));
    prefs.setInt('target', _targetNumber);
    prefs.remove('state');
  }

  // change between normal and scary mode
  void toggleMode() {
    if (_scaryMode) {
      // switch from scary mode to normal mode
      _scaryMode = false;
      _setIndexesFromNumbers();
      _saveValues(); // might have lost some numbers so must update now else the saved values will still include scary numbers
    } else {
      // switch from normal mode to scary mode
      _scaryMode = true;
      _setNumbersFromIndexes();
    }
  }

  String label(int label) => _labelLookup[label];

  // has enough data been entered to start solving?
  bool ready() => _countSelected() == numSourcesRequired && _targetNumber >= 100 && !(_sourceNumbers.any((n) => n == _targetNumber));
  
  void setSourceNumber(int index, int num) {
    _sourceNumbers[index] = num;
    _setIndexesFromNumbers();
    _saveValues();
  }

  // do our best to set _sourcesSelected from the current contents of _sourceNumbers
  void _setIndexesFromNumbers() {
    //assert(_scaryMode);
    allIndexes().forEach((i) {
      _sourcesSelected[i] = false;
    });
    _sourceNumbers.forEach((element) {
      if (element != 0) {
        for (var i in allIndexes()) {
          if (_sourcesSelected[i] == false && sourcesAllowed[i] == element) {
            _sourcesSelected[i] = true;
            break;
          }
        }
      }
    });
  }

  // do our best to set the numbers from the set index fields (which may mean discarding values that aren't allowed)
  void _setNumbersFromIndexes() {
    //assert(!_scaryMode);
    sourceNumberIndexes().forEach((i) {
      _setSourceNumber(i, 0);
    });
    var numberIndex = 0;
    _selectedIndexes().forEach((selectedIndex) {
      _setSourceNumber(numberIndex++, sourcesAllowed[selectedIndex]);
    });
  }

  // everything needed to set a source value, include the matching text field
  void _setSourceNumber(int index, int value) {
    _sourceNumbers[index] = value;
    _sourceControllers[index].text = value == 0 ? '' : value.toString();
  }

  // action to take when an unselected chip is pressed
  void addSource(int index) {
    if (_countSelected() < numSourcesRequired) {
      // only set it if we have less than the limit already
        _sourcesSelected[index] = true;
        _saveValues(); // copies values to text fields so no need to do it here
    }
  }

// action to take when a selected chip is pressed
  void removeSource(int index) {
      _sourcesSelected[index] = false;
      _saveValues(); // copies values to text fields so no need to do it here
  }

  // completely reset the game state - clear all values
  void reset() {
    _targetNumber = 0;
    _selectedIndexes().forEach((i) {
      _sourcesSelected[i] = false;
    });
    sourceNumberIndexes().forEach((i) {
      _sourceNumbers[i] = 0;
      _sourceControllers[i].text = '';
    });
    _saveValues();
    _targetTextController.clear();

  }
  
  // all the list indexes of allowed source numbers
  Iterable<int> allIndexes() => Iterable.generate(sourcesAllowed.length, (i) => i);

  // all the indexes of selected source numbers
  Iterable<int> _selectedIndexes() => allIndexes().where((i) => _sourcesSelected[i]);

  // all the indexes of the _sourceNumbers list
  Iterable<int> sourceNumberIndexes() => Iterable.generate(_sourceNumbers.length, (i) => i);

  // all the selected numbers
  Iterable<Value> selectedValues() => _sourceNumbers.indexed().map((each) => Value(each.value, each.index));

  // how many are selected? not exactly efficient but meh
  int _countSelected() => _sourceNumbers.where((n) => n != 0).length;
}
