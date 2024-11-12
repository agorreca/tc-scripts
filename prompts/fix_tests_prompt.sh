cat << 'EOF' > prompts/fix_tests_prompt.sh
#!/bin/bash

FIX_TESTS_PROMPT="Given the following code and its current test spec, improve or correct the test coverage to achieve 100% coverage using Vite tests with Vitest and Sinon (not Jest).
Please provide the complete corrected spec code. Do not add comments.
Avoid ESLint errors like ESLint: Unexpected any. Specify a different type. (@typescript-eslint/no-explicit-any)
Consider readonly and/or private methods and properties.
Make sure to import the following if using things like toBeInTheDocument: import '@testing-library/jest-dom'.
Pay attention to TS2339, TS2345 errors.
Do not use expect with toHaveTextContent or with i18n.
Also, do not use “vi.mock('react-i18next',...)”.
Remember not to use Jest.
Do not use \"as vi.Mock\" or \"as jest.Mock\". If you don’t know, resolve it with sinon.
Do not use \"act\" as it is deprecated. If you need information about an interface or the definition of an object, ask.
Do not add mock for i18next-react because I already have it defined in test-setup.
If applicable, watch out for the following errors:
- No QueryClient set, use QueryClientProvider to set one
- Cannot destructure property 'basename' of 'React__namespace.useContext(...)' as it is null.

Additionally, ensure that all arrow functions use '=> void 0' instead of '=> {}'.

----

"
EOF
