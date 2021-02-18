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
import 'solution_sender.dart';
import 'game_classes.dart';
import 'info_page.dart';
import 'text_util.dart';
import 'game_state.dart';

enum MainMenuOptions { changeMode, about }

class MainPage extends StatefulWidget {
  MainPage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with TextUtil {
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

  // UI messages
  static const String _instructions = '''
  To solve a Numbers game, select 6 "source" numbers then enter a target number between 100 and 999
  
  To solve a different game press the clear button, de-select/re-select to choose different source numbers, or edit the target number.
  ''';
  static const String _inProgress = 'Searching...';

  // now some genuine state
  GameState gameState = GameState();
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
  // a filter to prevent entry of anything other than digits, used on all text controllers
  TextInputFormatter _digitsOnlyFormatter;

  // some not-quite-state that gets initialized in the build method
  Color _dividerColor;
  Color _numberChipUnselectedColor;
  Color _numberChipSelectedColor;

  @override
  void initState() {
    super.initState();
    _initGameState();
    _digitsOnlyFormatter = FilteringTextInputFormatter.digitsOnly;
  }

  void _initGameState() async {
    await gameState.load(maybeSolve);
    setState(() {});
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
    final clearable = gameState.clearable();
    return Scaffold(
        appBar: AppBar(title: Text(widget.title), actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.clear),
            tooltip: 'Clear',
            onPressed: clearable ? _reset : null,
          ),
          PopupMenuButton<MainMenuOptions>(
            onSelected: (MainMenuOptions mode) {
              if (mode == MainMenuOptions.about) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => InfoPage()),
                );
              } else if (mode == MainMenuOptions.changeMode) {
                setState(() {
                  gameState.toggleMode();
                });
              }
            },
            itemBuilder: (context) => <PopupMenuEntry<MainMenuOptions>>[
              CheckedPopupMenuItem<MainMenuOptions>(
                enabled: true,
                checked: gameState.scaryMode,
                value: MainMenuOptions.changeMode,
                child: Text(
                  'Scary Numbers',
                ),
              ),
              PopupMenuItem<MainMenuOptions>(
                enabled: true,
                value: MainMenuOptions.about,
                child: const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text(
                    'About',
                  ),
                ),
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
            maxLength: GameState.maxTargetLength,
            style: _targetStyle,
            maxLines: 1,
            showCursor: true,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            controller: gameState.targetTextController,
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
                  gameState.targetNumber = int.parse(val);
                } else {
                  gameState.targetNumber = 0;
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
        : pad(_running ? _inProgress : _instructions, _theme.textTheme.bodyText1);
  }

  // converts a source number index to a selectable chip
  Widget _numberChip(int index, void Function(bool) action) {
    return Container(
        padding: EdgeInsets.only(left: 1.0, right: 1.0),
        child: FilterChip(
            selected: gameState.sourcesSelected[index],
            showCheckmark: false,
            onSelected: action,
            backgroundColor: _numberChipUnselectedColor,
            selectedColor: _numberChipSelectedColor,
            label: Text(
              GameState.sourcesAllowed[index].toString(),
              style: _sourceButtonStyle,
            )));
  }

  List<Widget> _allChips() {
    return gameState.allIndexes().map<Widget>((i) {
      return _numberChip(i, (bool selected) {
        setState(() {
          if (selected) {
            gameState.addSource(i);
            maybeSolve();
          } else {
            gameState.removeSource(i);
            _killSolver();
          }
        });
      });
    }).toList();
  }

  List<Widget> _allSourceFields() {
    return gameState.sourceNumberIndexes().map<Widget>((i) {
      return _numberField(i);
    }).toList();
  }

  Widget _numberField(int index) {
    return Flexible(
        child: Container(
            padding: EdgeInsets.fromLTRB(4, 2, 4, 2),
            width: _targetWidth,
            child: TextField(
                maxLength: GameState.maxSourceLength,
                style: _sourceStyle,
                maxLines: 1,
                showCursor: true,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                controller: gameState.sourceControllers[index],
                inputFormatters: [_digitsOnlyFormatter],
                decoration: InputDecoration(
                  hintText: '-',
                  border: const OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(1.0),
                  counterText: '', // don't show the counter'
                ),
                onChanged: (String val) async {
                  setState(() {
                    gameState.setSourceNumber(index, val.length > 0 ? int.parse(val) : 0);
                    _solutions.clear();
                    maybeSolve();
                  });
                })));
  }

  Widget _sourceEntryWidgets() {
    if (gameState.scaryMode) {
      return Row(
        children: _allSourceFields(),
      );
    } else {
      return Wrap(
        children: _allChips(),
      );
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
          gameState.label(v.label),
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
                      diffFormat(solution.result - gameState.targetNumber),
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

  void maybeSolve() {
    if (_running) {
      _killSolver();
    }
    if (gameState.ready()) {
      _initSolver();
    }
  }

  // reset everything - remove any solutions, reset the target to zero and clear all the selected source numbers
  void _reset() {
    setState(() {
      _killSolver();
      gameState.reset();
      _solutions.clear();
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
      while (_solutions.length > GameState.maxSolutions) {
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
    if (!gameState.scaryMode) {
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
    _sendToSolver.send({'numbers': gameState.selectedValues().toList(), 'target': gameState.targetNumber});
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
