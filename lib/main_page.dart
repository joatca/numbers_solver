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
import 'solution_sender.dart';
import 'info_page.dart';

class MainPage extends StatefulWidget {
  MainPage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
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
  static const _maxSolutions = 20; // plenty of options
  // the actual target number
  var _targetNumber = 0;

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

  List<Solution> _solutions = [];
  Isolate _solver;
  SendPort _sendToSolver;
  bool _running = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              builder: (context, orientation) => orientation == Orientation.portrait ? _verticalLayout() : _verticalLayout()),
        ));
  }

  Widget _verticalLayout() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          Wrap(
            children: _allChips(),
          ),
          _standardDivider(_dividerColor),
          _targetField(),
          _standardDivider(_solutions.length > 0 ? _dividerColor : Colors.transparent),
          _solutionList(),
        ],
      ),
    );
  }

  // Widget _horizontalLayout() {
  //   return Row(children: [
  //     _solutionList(),
  //     Column(
  //       // full contents of right section
  //       children: [
  //         // _actionButtonBar(),
  //         // _sourceButtons(0, 5, _smallChipWidth),
  //         // _sourceButtons(5, 10, _smallChipWidth),
  //         // _sourceButtons(10, 14, _largeChipWidth),
  //         Wrap(
  //           children: _availableChips(),
  //         ),
  //         _standardDivider(_dividerColor),
  //         _selectedDisplay(1),
  //         _standardDivider(_dividerColor),
  //         _targetField(),
  //       ],
  //     )
  //   ]);
  // }

  Divider _standardDivider(Color color) => Divider(
        thickness: _dividerThickness,
        color: _dividerColor,
        height: 2.0,
      );

  Widget _targetField() {
    return Flexible(
        flex: 1,
        child: Container(
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
                })));
  }

  Widget _solutionList() {
    return Expanded(
      // don't understand yet how this works, but needed to stop squishing everything else
      child: ListView.separated(
        itemCount: _solutions.length,
        separatorBuilder: (BuildContext context, int index) => _standardDivider(_dividerColor),
        itemBuilder: (BuildContext context, int index) => _resultTile(index),
      ),
    );
  }

  // all the list indexes of allowed source numbers
  Iterable<int> _allIndexes() => Iterable.generate(_sourcesAllowed.length, (i) => i);

  // all the indexes of select source numbers
  Iterable<int> _selectedIndexes() => _allIndexes().where((i) => _sourcesSelected[i]);

  // all the selected numbers
  Iterable<int> _selectedNumbers() => _selectedIndexes().map((i) => _sourcesAllowed[i]);

  // how many are selected? not exactly efficient but meh
  int _countSelected() => _selectedIndexes().length;

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
    return _allIndexes().map<Widget>((index) {
      return _numberChip(index, (bool selected) {
        if (selected) {
          addSource(index);
        } else {
          removeSource(index);
        }
      });
    }).toList();
  }

  Widget _resultTile(int index) => _solutionTile(_solutions[index]);

  // returns a value (number plus tag)
  Widget _valueTile(Value v) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          v.num.toString(),
          style: _numberStyle,
        ),
        Text(
          v.tag,
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
    final solutionWidgets = solution.steps.map<Widget>((step) => _stepTile(step)).toList();
    solutionWidgets.add(Text(
      "(${solution.away} away)",
      style: _numberStyle,
    ));
    return Wrap(
      children: solutionWidgets,
    );
  }

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
    if (_countSelected() < _numSourcesRequired) {
      // only set it if we have less than the limit already
      setState(() {
        _sourcesSelected[index] = true;
        maybeSolve();
      });
    }
    ;
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
      if (_solutions.length > 0) {
        if (solution.away < _solutions.first.away) {
          _solutions.clear(); // this solution is better than the ones we have, dump everything
        }
      }
      _solutions.add(solution);
      // we sort only by the shortest solution since we've already eliminated any that are further away
      _solutions.sort((a, b) => a.steps.length.compareTo(b.steps.length));
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
    _sendToSolver.send({'numbers': _selectedNumbers().toList(), 'target': _targetNumber});
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
