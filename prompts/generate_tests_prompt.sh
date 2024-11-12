cat << 'EOF' > prompts/generate_tests_prompt.sh
#!/bin/bash

GENERATE_TESTS_PROMPT="Given the following code, generate a minimal set of Vite tests with Vitest and Sinon (not Jest) that covers 100% coverage (in simple English) with “it”.
Please provide the complete code. I already have vitest and sinon installed. I just want the complete spec code.
Feel free to ask me for code, examples, explanations, interfaces, whatever you need to accomplish the task satisfactorily.
Also, please add the necessary data-testid for the QA team to automate, so give me the main code modifications to add them.
The data-testid must be unique and must not be added to React components.

Do not add comments.
Avoid ESLint errors like ESLint: Unexpected any. Specify a different type. (@typescript-eslint/no-explicit-any)
Consider readonly and/or private methods and properties.
Make sure to import the following if using things like toBeInTheDocument: import '@testing-library/jest-dom'.
Pay attention to TS2339, TS2345 errors.
Do not use expect with toHaveTextContent or with i18n.
Also, do not use “vi.mock('react-i18next',...)”.
Remember not to use Jest.
Do not use \"as vi.Mock\" or \"as jest.Mock\".
If you don’t know, resolve it with sinon.
Do not use \"act\" as it is deprecated.
If you need information about an interface or the definition of an object, ask.
Do not add mock for i18next-react because I already have it defined in test-setup.
If applicable, watch out for the following errors:
- No QueryClient set, use QueryClientProvider to set one
- Cannot destructure property 'basename' of 'React__namespace.useContext(...)' as it is null

Additionally, ensure that all arrow functions use '=> void 0' instead of '=> {}'.

----

"
EOF
