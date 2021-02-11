/*
This file is part of Numbers Solver - solve the Numbers game used in several
long-running European game shows

Copyright (C) 2021 Fraser McCrossan

flax is free software: you can redistribute it and/or modify
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
import 'package:numbers_solver/game_classes.dart';
import 'package:more/iterable.dart';
import 'solution_sender.dart';
import 'game_classes.dart';
import 'info_page.dart';
import 'text_util.dart';

class MainPage extends StatefulWidget {
  MainPage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with TextUtil {
  // all these variables *really* badly need reorganized

  static final List<int> _one2ten = Iterable.generate(10, (i) => i + 1).toList();
  // how many of each source number are allowed
  static final List<int> _sourcesAllowed = _one2ten + _one2ten + [25, 50, 75, 100];
  // which sources are currently selected?
  List<bool> _sourcesSelected = List<bool>.filled(_sourcesAllowed.length, false);
  // number of sources required before allowing a solve
  static const _numSourcesRequired = 6;
  // maximum length of the target number, used for the textfield
  static const _maxTargetLength = 3;
  // maximum number of solutions to store
  static const _maxSolutions = 50; // plenty of options
  // the actual target number
  var _targetNumber = 0;
  // to store the theme to avoid calling it all the time
  ThemeData theme;
  // used to jump focus to the target field in some circumstances
  FocusNode focusNode;

  TextEditingController targetTextController = TextEditingController();

  // UI options
  static const _targetWidth = 120.0;
  Color _dividerColor;
  static const _dividerThickness = 2.0;
  static const _stepSeparation = 6.0;
  static const _verticalStepSeparation = 3.0;
  Color _numberChipUnselectedColor;
  Color _numberChipSelectedColor;
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
  static final _sourceButtonStyle = TextStyle(
    fontSize: 18,
  );
  static final _resultUnder10Style = _targetStyle;
  static final _resultOver10Style = _resultUnder10Style.copyWith(color: Colors.red);

  static const String instructions = '''
  To solve a Number Game, select 6 "source" numbers then enter a target number between 100 and 999
  
  To solve a different puzzle press the clear button, de-select/re-select to choose different source numbers, or edit the target number.
  ''';

  List<Solution> _solutions = [];
  Isolate _solver;
  SendPort _sendToSolver;
  bool _running = false;

  // set up the focusnode so it can be used later
  @override
  void initState() {
    super.initState();
    focusNode = FocusNode();
  }

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    theme = Theme.of(context);
    _dividerColor = theme.textTheme.button.color.withOpacity(0.2);
    _numberChipUnselectedColor = theme.backgroundColor;
    _numberChipSelectedColor = theme.accentColor;
    final clearable = _sourcesSelected.any((i) => i) || _targetNumber > 0;
    return Scaffold(
        appBar: AppBar(title: Text(widget.title), actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.clear),
            tooltip: 'Clear',
            onPressed: clearable ? _resetPuzzle : null,
          ),
          IconButton(
            icon: Icon(Icons.info_outline),
            tooltip: 'About',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => InfoPage()),
              );
            },
          )
        ]),
        body: ChipTheme(
          data: ChipTheme.of(context).copyWith(shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10)))),
          child: OrientationBuilder(
              builder: (context, orientation) => orientation == Orientation.portrait ? _verticalLayout() : _horizontalLayout()),
        ));
  }

  Widget _verticalLayout() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.max,
      children: <Widget>[
        Wrap(
          children: _allChips(),
        ),
        _standardDivider(_dividerColor),
        _targetField(),
        _standardDivider(_solutions.length > 0 ? _dividerColor : Colors.transparent),
        Expanded(child: _solutionList()),
      ],
    );
  }

  Widget _horizontalLayout() {
    return Row(children: [
      Flexible(
        child: _solutionList(),
      ),
      Flexible(
          child: Column(
        // full contents of right section
        children: [
          Wrap(
            children: _allChips(),
          ),
          _standardDivider(_dividerColor),
          _targetField(),
        ],
      ))
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
            controller: targetTextController,
            focusNode: focusNode,
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
        : pad(instructions, theme.textTheme.bodyText1);
  }

  // all the list indexes of allowed source numbers
  Iterable<int> _allIndexes() => Iterable.generate(_sourcesAllowed.length, (i) => i);

  // all the indexes of select source numbers
  Iterable<int> _selectedIndexes() => _allIndexes().where((i) => _sourcesSelected[i]);

  // all the selected numbers
  Iterable<Value> _selectedValues() => _selectedIndexes().indexed().map((each) => Value(_sourcesAllowed[each.value], each.index));

  // how many are selected? not exactly efficient but meh
  int _countSelected() => _selectedIndexes().length;

  // converts a source number index to a selectable chip
  Widget _numberChip(int index, int colorNumber, void Function(bool) action) {
    return Container(
        padding: EdgeInsets.only(left: 1.0, right: 1.0),
        child: FilterChip(
            selected: _sourcesSelected[index],
            showCheckmark: false,
            onSelected: action,
            backgroundColor: _numberChipUnselectedColor,
            selectedColor: _numberChipSelectedColor, //colors[colorNumber],
            label: Text(
              _sourcesAllowed[index].toString(),
              style: _sourceButtonStyle,
            )));
  }

  List<Widget> _allChips() {
    int _selectedColorNumber = 0;
    return _allIndexes().map<Widget>((i) {
      return _numberChip(i, _sourcesSelected[i] ? _selectedColorNumber++ : _selectedColorNumber, (bool selected) {
        if (selected) {
          addSource(i);
        } else {
          removeSource(i);
        }
      });
    }).toList();
  }

  Widget _resultTile(int index) => _solutionTile(_solutions[index]);

  // returns a value (number plus tag)
  Widget _valueTile(Value v) {
    return Text(
        v.num.toString(),
        style: _numberStyle,
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
            padding: EdgeInsets.fromLTRB(4, 0, 8, 0),
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

  // action to take when an unselected chip is pressed
  void addSource(int index) {
    final numSelected = _countSelected();
    if (numSelected < _numSourcesRequired) {
      // only set it if we have less than the limit already
      setState(() {
        _sourcesSelected[index] = true;
        if (numSelected == _numSourcesRequired - 1 && _targetNumber == 0) {
          // we just set the last one *and* the target field is unset
          focusNode.requestFocus();
        }
        maybeSolve();
      });
    }
  }

// action to take when a selected chip is pressed
  void removeSource(int index) {
    setState(() {
      _sourcesSelected[index] = false;
      _solutions.clear();
    });
  }

  void maybeSolve() {
    if (_running) {
      _killSolver();
    } else {
      final readyToSolve = _countSelected() == _numSourcesRequired && _targetNumber >= 100;
      final sourcesIncludeTarget = _selectedIndexes().any((i) => _sourcesAllowed[i] == _targetNumber);
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
      _solutions.clear();
      targetTextController.clear();
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
      _solutions.sort((a, b) => (a.away == b.away) ? a.steps.length.compareTo(b.steps.length) : a.away.compareTo(b.away));
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
    setState(() {
      FocusScope.of(context).unfocus(); // dismiss the keyboard if possible
    });
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
