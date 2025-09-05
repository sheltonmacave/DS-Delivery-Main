import 'package:flutter/material.dart';

const String fontTitle = 'SpaceGrotesk';
const String fontBody = 'Inter';

const TextTheme appTextTheme = TextTheme(
  displayLarge: TextStyle(fontFamily: fontTitle, fontSize: 57, fontWeight: FontWeight.w400),
  displayMedium: TextStyle(fontFamily: fontTitle, fontSize: 45, fontWeight: FontWeight.w400),
  displaySmall: TextStyle(fontFamily: fontTitle, fontSize: 36, fontWeight: FontWeight.w400),
  headlineLarge: TextStyle(fontFamily: fontTitle, fontSize: 32, fontWeight: FontWeight.w700),
  headlineMedium: TextStyle(fontFamily: fontTitle, fontSize: 28, fontWeight: FontWeight.w700),
  headlineSmall: TextStyle(fontFamily: fontTitle, fontSize: 24, fontWeight: FontWeight.w700),
  titleLarge: TextStyle(fontFamily: fontBody, fontSize: 22, fontWeight: FontWeight.w600),
  titleMedium: TextStyle(fontFamily: fontBody, fontSize: 16, fontWeight: FontWeight.w500),
  titleSmall: TextStyle(fontFamily: fontBody, fontSize: 14, fontWeight: FontWeight.w500),
  bodyLarge: TextStyle(fontFamily: fontBody, fontSize: 16, fontWeight: FontWeight.w400),
  bodyMedium: TextStyle(fontFamily: fontBody, fontSize: 14, fontWeight: FontWeight.w400),
  bodySmall: TextStyle(fontFamily: fontBody, fontSize: 12, fontWeight: FontWeight.w400),
  labelLarge: TextStyle(fontFamily: fontBody, fontSize: 14, fontWeight: FontWeight.w500),
  labelMedium: TextStyle(fontFamily: fontBody, fontSize: 12, fontWeight: FontWeight.w500),
  labelSmall: TextStyle(fontFamily: fontBody, fontSize: 11, fontWeight: FontWeight.w500),
);
