/*
Numbers Solver - solve the Numbers game used in several long-running European game shows

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


import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  static const title = "Numbers Game Solver";

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: title,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MainPage(title: title),
    );
  }
}

class MainPage extends StatefulWidget {
  MainPage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  static final smallNumbers = List.generate(10, (i) => i + 1);
  static final bigNumbers = [25, 50, 75, 100];
  static final sourceNumbers = smallNumbers + smallNumbers + bigNumbers;
  var sourceSelected = sourceNumbers.map((e) => false).toList(growable: false);
  static const sourceRequired = 6;
  static const maxTargetLength = 3;
  var target_number = 0;

  @override
  Widget build(BuildContext context) {
    final remaining = sourceRequired - countSelected();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Text(remaining > 1
                ? 'Select ${remaining} more puzzle numbers:'
                : (remaining == 1
                    ? 'Select 1 more puzzle number'
                    : 'Puzzle numbers OK')),
            numberRow(0, smallNumbers.length),
            numberRow(smallNumbers.length, smallNumbers.length),
            numberRow(smallNumbers.length * 2, bigNumbers.length),
            Text(target_number == 0
                ? 'Enter 3 digits for target number:'
                : (target_number < 10
                    ? 'Enter 2 digits:'
                    : (target_number < 100
                        ? 'Enter 1 digit:'
                        : 'Target number OK'))),
            TextField(
                maxLength: maxTargetLength,
                maxLines: 1,
                keyboardType: TextInputType.number,
                onChanged: (String val) async {
                  setState(() {
                    if (val.length > 0) {
                      target_number = int.parse(val);
                    } else {
                      target_number = 0;
                    }
                  });
                })
          ],
        ),
      ),
    );
  }

  void toggleNumber(int n) {
    setState(() {
      if (sourceSelected[n]) {
        // it is currently select, deselect it
        sourceSelected[n] = false;
      } else {
        // not selected, select it only if we don't already have 6 selected
        if (countSelected() < sourceRequired) {
          sourceSelected[n] = true;
        }
      }
    });
  }

  int countSelected() {
    return sourceSelected.fold(
        0,
        (previousValue, element) =>
            element ? previousValue + 1 : previousValue);
  }

  // returns a row of source number chips given by the offset and length
  Widget numberRow(int offset, int length) {
    return Center(
        child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: Iterable.generate(length, (i) => i + offset)
                .map((n) => ActionChip(
                      label: Text(sourceNumbers[n].toString()),
                      onPressed: () => toggleNumber(n),
                      backgroundColor:
                          sourceSelected[n] ? Colors.blueAccent : Colors.white,
                    ))
                .toList()));
  }
}
