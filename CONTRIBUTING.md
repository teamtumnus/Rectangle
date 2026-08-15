# Contributing

## Feature Requests

Rectangle is not accepting any new feature requests at this time, sorry. You can file a feature request for a feature that you plan to implement and submit a pull request for, so that the feature can be reviewed and you will know ahead of time if the feature will be rejected.  

## Bugs

Please search through the existing issues, open and closed, before filing a new bug.
Add the version of Rectangle, the version of the OS, and screenshots or videos as necessary.

## Coding Style

Please match the existing coding style as much as possible.

## Development dependencies

This fork has no remote Swift package dependencies. `LocalPackages/RectangleShortcuts` is an in-repository, statically linked package that uses only Apple system frameworks. Run its independent tests with `swift test --package-path LocalPackages/RectangleShortcuts`, and run `scripts/verify-dependency-boundary.sh` before submitting changes.

## License

By contributing to Rectangle you agree that your contributions will be licensed under its MIT license.

## Incentives

The upstream Rectangle project is used by the [Multitouch](https://multitouch.app) and [Rectangle Pro](https://rectangleapp.com/pro) apps. See [rxhanson/Rectangle](https://github.com/rxhanson/Rectangle) for the upstream project's contribution incentives.
