# Release process

1. Update version in /mix.exs & /README.md

2. Ensure /CHANGELOG.md is updated, versioned and add the current date

3. Run `mix test.check` and make sure it completes successfully

4. Commit changes above with title "Release v`{{ version }}`"

5. Generate new tag v`{{ version }}`

6. Verify that all automated CI completes successfully

7. Run `mix hex.publish`
