# Release process

1. Update version in /mix.exs & /README.md

2. Ensure /CHANGELOG.md is updated, versioned and add the current date

3. Commit changes above with title "Release v`{{ version }}`"

4. Generate new tag v`{{ version }}`

5. Verify that all automated CI completes successfully

6. Run `mix hex.publish`
