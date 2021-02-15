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

import 'dart:isolate';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:numbers_solver/game_classes.dart';
import 'package:more/iterable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'solution_sender.dart';
import 'game_classes.dart';
import 'info_page.dart';
import 'text_util.dart';

enum EntryMode { normal, scary }
enum MainMenuOptions { changeMode, about }

class MainPage extends StatefulWidget {
  MainPage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with TextUtil {
  // first some constants (or effective constants)

  // maximum length of the target number, used for the target textfield
  static const _maxTargetLength = 3;
  // maximum length of the source numbers, used for the source textfields in scary mode
  static const _maxSourceLength = 3;
  // maximum number of solutions to store
  static const _maxSolutions = 50; // plenty of options
  // number of sources required before allowing a solve
  static const _numSourcesRequired = 6;

  // some UI construction constants
  static const _targetWidth = 120.0;
  static const _dividerThickness = 2.0;
  static const _stepSeparation = 6.0;
  static const _verticalStepSeparation = 3.0;
  static final _numberStyle = TextStyle(
    fontSize: 16,
  );
  static final _tagStyle = TextStyle(
    fontSize: 8,
    fontStyle: FontStyle.italic,
  );
  static final _targetStyle = TextStyle(
    fontSize: 20,
  );
  static final _sourceStyle = TextStyle(
    fontSize: 16,
  );
  static final _sourceButtonStyle = TextStyle(
    fontSize: 18,
  );
  static final _resultUnder10Style = _targetStyle;
  static final _resultOver10Style = _resultUnder10Style.copyWith(color: Colors.red);

  // stuff to generate the number subscript labels

  // characters to use as labels
  static final int _firstLabelCode = 'A'.codeUnitAt(0);
  // labels start at zero; the source numbers first and then intermediates, so we want _numSourcesRequired of the first then the
  // same number of the second
  static final List<String> _labelLookup =
      Iterable.generate(_numSourcesRequired * 2, (i) => i + _firstLabelCode).map((code) => String.fromCharCode(code)).toList();

  // UI messages
  static const String _instructions = '''
  To solve a Numbers game, select 6 "source" numbers then enter a target number between 100 and 999
  
  To solve a different game press the clear button, de-select/re-select to choose different source numbers, or edit the target number.
  ''';
  static const String _inProgress = 'Searching...';

  // list to help construct _sourcesAllowed
  static final List<int> _one2ten = Iterable.generate(10, (i) => i + 1).toList();
  // how many of each source number are allowed
  static final List<int> _sourcesAllowed = _one2ten + _one2ten + [25, 50, 75, 100];

  // now some genuine state

  // regular or scary mode?
  EntryMode _entryMode = EntryMode.normal;
  // the actual target number
  var _targetNumber = 0;
  // which sources are currently selected?
  List<bool> _sourcesSelected = List<bool>.filled(_sourcesAllowed.length, false);
  // actual numbers - set by the chips as well as manually in scary mode
  List<int> _sourceNumbers = List<int>.filled(_numSourcesRequired, 0);
  // the list of solutions found (so far)
  List<Solution> _solutions = [];
  // easy way to track whether we are running or now, used to tweak the UI
  bool _running = false;

  // the Isolate running the solver - saved so we can kill it
  Isolate _solver;
  // port used to send the game to the solver
  SendPort _sendToSolver;

  // to store the theme to avoid calling it all the time
  ThemeData _theme;
  // used to attempt to dismiss the keyboard once we start solving, and to set the initial target number from saved prefs
  TextEditingController _targetTextController = TextEditingController();
  // used to set source numbers from saved prefs
  List<TextEditingController> _sourceControllers;
  // a filter to prevent entry of anything other than digits, used on all text controllers
  TextInputFormatter _digitsOnlyFormatter;

  // some not-quite-state that gets initialized in the build method
  Color _dividerColor;
  Color _numberChipUnselectedColor;
  Color _numberChipSelectedColor;

  @override
  void initState() {
    super.initState();
    _loadPreviousValues();
    _sourceControllers = _sourceNumbers.map((s) => TextEditingController()).toList(); // generate enough of them on the fly
    _digitsOnlyFormatter = FilteringTextInputFormatter.digitsOnly;
  }

  void _loadPreviousValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
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
          if (!_sourceNumbers.every((sn) => sn == 0 || _sourcesAllowed.any((sa) => sn == sa))) {
            _entryMode = EntryMode.scary; // we found some numbers outside regular numbers
          } else {
            _setIndexesFromNumbers();
          }
          maybeSolve();
        } on Exception catch (e) {
          // probably some parsing error, we don't care, just fail to load
          print("exception: $e");
        }
      }
    });
  }

  void _saveValues() async {
    if (_entryMode == EntryMode.normal) {
      _setNumbersFromIndexes();
    }
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('sources', _sourceNumbers.map((n) => n.toString()).join(','));
    prefs.setInt('target', _targetNumber);
    prefs.remove('state');
  }

  @override
  void dispose() {
    _killSolver();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _theme = Theme.of(context);
    _dividerColor = _theme.textTheme.button.color.withOpacity(0.2);
    _numberChipUnselectedColor = _theme.backgroundColor;
    _numberChipSelectedColor = _theme.accentColor;
    final clearable = _sourcesSelected.any((i) => i) || _targetNumber > 0;
    return Scaffold(
        appBar: AppBar(title: Text(widget.title), actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.clear),
            tooltip: 'Clear',
            onPressed: clearable ? _resetPuzzle : null,
          ),
          PopupMenuButton<MainMenuOptions>(
            onSelected: (MainMenuOptions mode) {
              if (mode == MainMenuOptions.about) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => InfoPage()),
                );
              } else if (mode == MainMenuOptions.changeMode) {
                _toggleMode();
              }
            },
            itemBuilder: (context) => <PopupMenuEntry<MainMenuOptions>>[
              PopupMenuItem<MainMenuOptions>(
                enabled: true,
                value: MainMenuOptions.changeMode,
                child: Text(
                  _entryMode == EntryMode.normal ? 'Scary Mode' : 'Normal Mode',
                ),
              ),
              PopupMenuItem<MainMenuOptions>(
                enabled: true,
                value: MainMenuOptions.about,
                child: const Text('About'),
              ),
            ],
          )
        ]),
        body: ChipTheme(
          data: ChipTheme.of(context).copyWith(shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10)))),
          child: LayoutBuilder(
              builder: (context, constraints) => constraints.maxWidth > 550 ? _horizontalLayout() : _verticalLayout()),
        ));
  }

  Widget _verticalLayout() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.max,
      children: <Widget>[
        _sourceEntryWidgets(),
        _standardDivider(_dividerColor),
        _targetField(),
        _standardDivider(_solutions.length > 0 ? _dividerColor : Colors.transparent),
        Expanded(child: _solutionList()),
      ],
    );
  }

  Widget _horizontalLayout() {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Flexible(
        child: _solutionList(),
        flex: 3,
      ),
      Flexible(
        child: Column(
          // full contents of right section
          children: [
            _sourceEntryWidgets(),
            _standardDivider(_dividerColor),
            _targetField(),
          ],
        ),
        flex: 2,
      )
    ]);
  }

  Divider _standardDivider(Color color) => Divider(
        thickness: _dividerThickness,
        color: _dividerColor,
        height: 2.0,
      );

  Widget _targetField() {
    return Container(
        padding: EdgeInsets.all(8.0),
        width: _targetWidth,
        child: TextField(
            maxLength: _maxTargetLength,
            style: _targetStyle,
            maxLines: 1,
            showCursor: true,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            controller: _targetTextController,
            inputFormatters: [_digitsOnlyFormatter],
            decoration: InputDecoration(
              hintText: 'Target',
              border: const OutlineInputBorder(),
              contentPadding: EdgeInsets.all(1.0),
              counterText: '', // don't show the counter'
            ),
            onChanged: (String val) async {
              setState(() {
                if (val.length > 0) {
                  _targetNumber = int.parse(val);
                } else {
                  _targetNumber = 0;
                }
                _saveValues();
                _solutions.clear();
                maybeSolve();
              });
            }));
  }

  Widget _solutionList() {
    return _solutions.length > 0
        ? ListView.separated(
            itemCount: _solutions.length,
            separatorBuilder: (BuildContext context, int index) => _standardDivider(_dividerColor),
            itemBuilder: (BuildContext context, int index) => _resultTile(index),
          )
        : pad(_running ? _inProgress : _instructions, _theme.textTheme.bodyText1);
  }

  // all the list indexes of allowed source numbers
  Iterable<int> _allIndexes() => Iterable.generate(_sourcesAllowed.length, (i) => i);

  // all the indexes of selected source numbers
  Iterable<int> _selectedIndexes() => _allIndexes().where((i) => _sourcesSelected[i]);

  // all the indexes of the _sourceNumbers list
  Iterable<int> _sourceNumberIndexes() => Iterable.generate(_sourceNumbers.length, (i) => i);

  // all the selected numbers
  Iterable<Value> _selectedValues() => _sourceNumbers.indexed().map((each) => Value(each.value, each.index));

  // how many are selected? not exactly efficient but meh
  int _countSelected() => _sourceNumbers.where((n) => n != 0).length;

  // converts a source number index to a selectable chip
  Widget _numberChip(int index, void Function(bool) action) {
    return Container(
        padding: EdgeInsets.only(left: 1.0, right: 1.0),
        child: FilterChip(
            selected: _sourcesSelected[index],
            showCheckmark: false,
            onSelected: action,
            backgroundColor: _numberChipUnselectedColor,
            selectedColor: _numberChipSelectedColor,
            label: Text(
              _sourcesAllowed[index].toString(),
              style: _sourceButtonStyle,
            )));
  }

  List<Widget> _allChips() {
    return _allIndexes().map<Widget>((i) {
      return _numberChip(i, (bool selected) {
        if (selected) {
          addSource(i);
        } else {
          removeSource(i);
        }
      });
    }).toList();
  }

  List<Widget> _allSourceFields() {
    return _sourceNumberIndexes().map<Widget>((i) {
      return _numberField(i);
    }).toList();
  }

  Widget _numberField(int index) {
    return Flexible(
        child: Container(
            padding: EdgeInsets.fromLTRB(4, 2, 4, 2),
            width: _targetWidth,
            child: TextField(
                maxLength: _maxSourceLength,
                style: _sourceStyle,
                maxLines: 1,
                showCursor: true,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                controller: _sourceControllers[index],
                inputFormatters: [_digitsOnlyFormatter],
                decoration: InputDecoration(
                  hintText: '-',
                  border: const OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(1.0),
                  counterText: '', // don't show the counter'
                ),
                onChanged: (String val) async {
                  setState(() {
                    _sourceNumbers[index] = val.length > 0 ? int.parse(val) : 0;
                    _setIndexesFromNumbers();
                    _saveValues();
                    _solutions.clear();
                    maybeSolve();
                  });
                })));
  }

  Widget _sourceEntryWidgets() {
    if (_entryMode == EntryMode.normal) {
      return Wrap(
        children: _allChips(),
      );
    } else {
      return Row(children: _allSourceFields());
    }
  }

  Widget _resultTile(int index) => _solutionTile(_solutions[index]);

  // returns a value (number plus tag)
  Widget _valueTile(Value v) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          v.num.toString(),
          style: _numberStyle,
        ),
        Text(
          _labelLookup[v.label],
          style: _tagStyle,
        ),
      ],
    );
  }

  Widget _stepTile(SolutionStep step) {
    return Container(
        margin: EdgeInsets.fromLTRB(0.0, 0.0, _stepSeparation, _verticalStepSeparation),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _valueTile(step.v1),
            Text(
              step.op.toString(),
              style: _numberStyle,
            ),
            _valueTile(step.v2),
            Text(
              '=',
              style: _numberStyle,
            ),
            _valueTile(step.result),
          ],
        ));
  }

  Widget _solutionTile(Solution solution) {
    return Row(
      children: [
        // steps
        Expanded(
          child: Wrap(
            children: solution.steps.map<Widget>((step) => _stepTile(step)).toList(),
          ),
        ),
        // status
        Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 0),
            child: Center(
              child: solution.away == 0
                  ? Icon(
                      Icons.done,
                      color: Colors.green,
                    )
                  : Text(
                      diffFormat(solution.result - _targetNumber),
                      style: solution.away < 10 ? _resultUnder10Style : _resultOver10Style,
                    ),
            )),
      ],
    );
  }

  String diffFormat(int diff) => diff < 0 ? diff.toString() : "+$diff";

  double textWidth(int number, TextStyle style) {
    final Size size = (TextPainter(
            text: TextSpan(text: number.toString(), style: style),
            maxLines: 1,
            textScaleFactor: MediaQuery.of(context).textScaleFactor,
            textDirection: TextDirection.ltr)
          ..layout())
        .size;
    return size.width;
  }

  // change between normal and scary mode
  void _toggleMode() {
    setState(() {
      if (_entryMode == EntryMode.normal) {
        // switch from normal mode to scary mode
        _entryMode = EntryMode.scary;
        _setNumbersFromIndexes();
      } else {
        // switch from scary mode to normal mode
        _entryMode = EntryMode.normal;
        _setIndexesFromNumbers();
        _saveValues(); // might have lost some numbers so must update now else the saved values will still include scary numbers
      }
    });
  }

  // do our best to set _sourcesSelected from the current contents of _sourceNumbers
  void _setIndexesFromNumbers() {
    _allIndexes().forEach((i) {
      _sourcesSelected[i] = false;
    });
    _sourceNumbers.forEach((element) {
      if (element != 0) {
        for (var i in _allIndexes()) {
          if (_sourcesSelected[i] == false && _sourcesAllowed[i] == element) {
            _sourcesSelected[i] = true;
            break;
          }
        }
      }
    });
  }

  // do our best to set the numbers from the set index fields (which may mean discarding values that aren't allowed)
  void _setNumbersFromIndexes() {
    _sourceNumberIndexes().forEach((i) {
      _setSourceNumber(i, 0);
    });
    var numberIndex = 0;
    _selectedIndexes().forEach((selectedIndex) {
      _setSourceNumber(numberIndex++, _sourcesAllowed[selectedIndex]);
    });
  }

  // everything needed to set a source value, include the matching text field
  void _setSourceNumber(int index, int value) {
    _sourceNumbers[index] = value;
    _sourceControllers[index].text = value == 0 ? '' : value.toString();
  }

  // action to take when an unselected chip is pressed
  void addSource(int index) {
    if (_countSelected() < _numSourcesRequired) {
      // only set it if we have less than the limit already
      setState(() {
        _sourcesSelected[index] = true;
        _saveValues(); // copies values to text fields so no need to do it here
        maybeSolve();
      });
    }
  }

// action to take when a selected chip is pressed
  void removeSource(int index) {
    setState(() {
      _sourcesSelected[index] = false;
      _saveValues(); // copies values to text fields so no need to do it here
      _solutions.clear();
    });
  }

  void maybeSolve() {
    if (_running) {
      _killSolver();
    } else {
      final readyToSolve = _countSelected() == _numSourcesRequired && _targetNumber >= 100;
      final sourcesIncludeTarget = _sourceNumbers.any((n) => n == _targetNumber);
      if (readyToSolve && !sourcesIncludeTarget) {
        _initSolver();
      }
    }
  }

  // reset everything - remove any solutions, reset the target to zero and clear all the selected source numbers
  void _resetPuzzle() {
    setState(() {
      _killSolver();
      _targetNumber = 0;
      _selectedIndexes().forEach((i) {
        _sourcesSelected[i] = false;
      });
      _sourceNumberIndexes().forEach((i) {
        _sourceNumbers[i] = 0;
        _sourceControllers[i].text = '';
      });
      _saveValues();
      _solutions.clear();
      _targetTextController.clear();
    });
  }

  // solutionSender sends a null once the search is complete; if so then kill it, otherwise add the solution it just found
  void _receiveSolution(data) {
    if (data == null) {
      _killSolver();
    } else {
      setState(() {
        _addSolution(data);
      });
    }
  }

  // add the latest solution then trim everything down to the "best" - prefer closer to the target and shorter solutions
  void _addSolution(solution) {
    assert(solution is Solution);
    if (solution is Solution) {
      // this makes it typesafe inside the if block
      _solutions.add(solution);
      // we sort by the closest then by shortest
      _solutions.sort();
      while (_solutions.length > _maxSolutions) {
        _solutions.removeLast();
      }
    }
  }

  // this sets up all the ports to and from the solver isolate, registers a callback to listen, then starts up the isolate
  Future<SendPort> _startSolverListener() async {
    Completer completer = new Completer<SendPort>();
    ReceivePort fromSolver = ReceivePort();

    fromSolver.listen((data) {
      if (data is SendPort) {
        completer.complete(data); // this is how we'll send games to the solver Isolate
      } else {
        _receiveSolution(data); // otherwise this is how we receive solutions
      }
    });

    _solver = await Isolate.spawn(solutionSender, fromSolver.sendPort);
    return completer.future;
  }

  void _hideKeyboard() {
    if (_entryMode == EntryMode.normal) {
      // only tweak the focus if we are in normal mode - it's too annoying in scary mode
      setState(() {
        FocusScope.of(context).unfocus(); // dismiss the keyboard if possible
      });
    }
  }

  // called when the Solve button is pressed; clear the onscreen kb if possible, clear the solutions then start up the solver isolate
  void _initSolver() async {
    _hideKeyboard();
    _solutions.clear();
    _sendToSolver = await _startSolverListener();
    // we now have a running isolate and a port to send it the game
    _sendToSolver.send({'numbers': _selectedValues().toList(), 'target': _targetNumber});
    setState(() {
      _running = true;
    });
  }

  // kill the solver isolate if it's running then reset the running state
  void _killSolver() {
    setState(() {
      _solver?.kill(priority: Isolate.immediate);
      _solver = null;
      _running = false;
    });
  }
}
