return {
    "mfussenegger/nvim-dap",
    dependencies = {
        "rcarriga/nvim-dap-ui",
        "nvim-neotest/nvim-nio", -- required by dap-ui
        "theHamsta/nvim-dap-virtual-text", -- inline variable values
        "mfussenegger/nvim-dap-python",
    },
    keys = {
        { "<F5>", function() require("dap").continue() end, desc = "Debug: start / continue" },
        { "<F10>", function() require("dap").step_over() end, desc = "Debug: step over" },
        { "<F11>", function() require("dap").step_into() end, desc = "Debug: step into" },
        { "<F12>", function() require("dap").step_out() end, desc = "Debug: step out" },
        { "<leader>bb", function() require("dap").toggle_breakpoint() end, desc = "Toggle breakpoint" },
        { "<leader>bB", function() require("dap").set_breakpoint(vim.fn.input("Condition: ")) end, desc = "Conditional breakpoint" },
        { "<leader>bl", function() require("dap").set_breakpoint(nil, nil, vim.fn.input("Log message: ")) end, desc = "Log point" },
        { "<leader>bc", function() require("dap").clear_breakpoints() end, desc = "Clear all breakpoints" },
        { "<leader>bu", function() require("dapui").toggle() end, desc = "Toggle debug UI" },
        { "<leader>be", function() require("dapui").eval() end, mode = { "n", "v" }, desc = "Eval expression" },
        { "<leader>bR", function() require("dap").repl.toggle() end, desc = "Toggle REPL" },
        { "<leader>br", function() require("dap").run_last() end, desc = "Run last config" },
        { "<leader>bt", function() require("dap").terminate() end, desc = "Terminate session" },
    },
    config = function()
        local dap = require("dap")
        local dapui = require("dapui")

        dapui.setup()
        require("nvim-dap-virtual-text").setup()

        -- open/close the UI automatically
        dap.listeners.before.attach.dapui_config = function() dapui.open() end
        dap.listeners.before.launch.dapui_config = function() dapui.open() end
        dap.listeners.before.event_terminated.dapui_config = function() dapui.close() end
        dap.listeners.before.event_exited.dapui_config = function() dapui.close() end

        -- signs
        vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticError" })
        vim.fn.sign_define("DapBreakpointCondition", { text = "◆", texthl = "DiagnosticWarn" })
        vim.fn.sign_define("DapLogPoint", { text = "◆", texthl = "DiagnosticInfo" })
        vim.fn.sign_define("DapStopped", { text = "▶", texthl = "DiagnosticOk", linehl = "Visual", numhl = "DiagnosticOk" })

        ---------------------------------------------------------------------
        -- Python (debugpy)
        -- dap-python adds "Launch file", "Launch file with arguments", etc.
        -- and automatically uses the active project venv for the debuggee.
        ---------------------------------------------------------------------
        local debugpy = vim.fn.stdpath("data") .. "/mason/packages/debugpy/venv/bin/python"
        require("dap-python").setup(vim.uv.fs_stat(debugpy) and debugpy or "python3")

        ---------------------------------------------------------------------
        -- C / C++ (codelldb)
        ---------------------------------------------------------------------
        dap.adapters.codelldb = {
            type = "server",
            port = "${port}",
            executable = {
                command = "codelldb", -- mason puts this on PATH
                args = { "--port", "${port}" },
            },
        }

        local function pick_exe()
            return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
        end

        local native = {
            {
                name = "Launch executable",
                type = "codelldb",
                request = "launch",
                program = pick_exe,
                cwd = "${workspaceFolder}",
                stopOnEntry = false,
                terminal = "integrated", -- needed if your program reads stdin (cin, scanf)
            },
            {
                name = "Launch executable (with args)",
                type = "codelldb",
                request = "launch",
                program = pick_exe,
                args = function()
                    return vim.split(vim.fn.input("Args: "), " ", { trimempty = true })
                end,
                cwd = "${workspaceFolder}",
                stopOnEntry = false,
                terminal = "integrated",
            },
        }
        dap.configurations.c = native
        dap.configurations.cpp = native
    end,
}
