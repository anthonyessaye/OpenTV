# Third-party notices

## NextPlayer

The following Gradle modules are vendored, largely unmodified, from
[NextPlayer](https://github.com/anilbeesetti/nextplayer) by anilbeesetti:

```
core/common      core/model      feature/player
core/data        core/media      feature/settings
core/database    core/ui         feature/videopicker
core/datastore   core/domain
```

They retain the upstream package namespace `dev.anilbeesetti.nextplayer`.

NextPlayer is licensed under the **GNU General Public License v3.0**. The full
text is included at [`licenses/GPL-3.0.txt`](licenses/GPL-3.0.txt) and applies
to every file in the modules listed above.

The upstream revision these modules were copied from was not recorded at the
time of vendoring and is not currently known. This should be established before
any attempt to sync upstream fixes.

### Unresolved license conflict

The repository's own `LICENSE` is Creative Commons Attribution-NonCommercial
4.0. GPL-3.0 and a non-commercial restriction do not compose: the GPL does not
permit adding restrictions beyond its own terms, and CC BY-NC is not a
GPL-compatible license.

This notice records the upstream license and attribution, which were previously
absent. It does **not** resolve the conflict. Distributing a combined work under
the current terms is not something this file makes lawful.

Two paths close it:

1. Remove the vendored modules. They are scheduled for deletion when the custom
   player lands, which retires the conflict permanently.
2. Relicense this repository under GPL-3.0-compatible terms.

This is a decision for the project owner, not one that can be made in code.
