# Contributing to OmniCore

First off, thank you for considering contributing to OmniCore! It's people like you that make OmniCore such a great app.

## Where do I go from here?

If you've noticed a bug or have a feature request, make sure to check our [Issues](https://github.com/ShadowByte01/omni-core/issues) to see if someone else has already created a ticket. If not, go ahead and [make one](https://github.com/ShadowByte01/omni-core/issues/new)!

## Fork & create a branch

If this is something you think you can fix, then fork OmniCore and create a branch with a descriptive name.

```bash
git checkout -b feature/your-awesome-feature
```

## Get the test suite running

Make sure your code works and compiles smoothly. OmniCore requires Flutter 3.27+ and Dart 3.5+.
To run the project locally:

```bash
flutter pub get
flutter run
```

## Implement your fix or feature

At this point, you're ready to make your changes! Feel free to ask for help; everyone is a beginner at first.

## Make a Pull Request

At this point, you should switch back to your master branch and make sure it's up to date with OmniCore's master branch:

```bash
git remote add upstream https://github.com/ShadowByte01/omni-core.git
git fetch upstream
git merge upstream/main
```

Then push your feature branch:

```bash
git push origin feature/your-awesome-feature
```

Finally, go to GitHub and make a Pull Request! We'll review your code and merge it in.

## Style Guide

We try to keep our code clean and follow the standard Flutter/Dart style guides. Please make sure your code does not contain warnings from the static analyzer.

Thank you for contributing!
