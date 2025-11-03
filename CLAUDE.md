- do not build dmg and tag unless i ask, commit periodically but don't bump the version
- use HIG best practices as much as possible, don't design custom componets
- be very conservative with versions, keep it in 0.0.6 unless explicitly told
- The Release build needs hardened runtime and shouldn't include the get-task-allow entitlement.
- when i say release new version it means
1. bump patch version, unless told otherwise
2. commit all code
3. notarize
4. build dmg
5. only when dmg is released and working push everything to github, dmg, notarized app, etc
6. make sure that the code in github and main are up to date to the latest release