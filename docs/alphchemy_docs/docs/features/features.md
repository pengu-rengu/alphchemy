# Features

A **feature** is a value computed from OHLC bars. Every feature produces one value per bar, from start to end.

## Feature ID

A short name for a given feature, which must be unique across all features in a **strategy**.

## Normalization

Some features are divided by the OHLC prices they were computed with, resulting in small ratio around 1.0
