import 'package:flutter/material.dart';

abstract class TextUtil {
  // prevent instantiation
  factory TextUtil._() => null;

  pad(String text, TextStyle style) {
    return Padding(
        padding: EdgeInsets.all(8.0),
        child: Text(
          text,
          style: style,
        ));
  }
}
