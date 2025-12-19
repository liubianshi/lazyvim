--- Overseer task generator for go-task (Task)
--- Automatically discovers and creates tasks from Taskfile.yml/yaml

local overseer = require("overseer")

--- Command name for the task runner
local CMD_TASK = "go-task"

--- Valid Taskfile names to check for
local TASKFILE_NAMES = {
  "Taskfile.yml",
  "Taskfile.yaml",
  "taskfile.yml",
  "taskfile.yaml",
}

--- Check if a Taskfile exists in the given directory
--- @param dir string The directory to check
--- @return boolean True if any valid Taskfile exists
local function has_taskfile(dir)
  for _, filename in ipairs(TASKFILE_NAMES) do
    if vim.fn.filereadable(vim.fs.joinpath(dir, filename)) == 1 then
      return true
    end
  end
  return false
end

--- Parse task list from go-task JSON output
--- @param stdout string JSON output from go-task --list-all --json
--- @return table|nil Parsed tasks or nil on error
local function parse_tasks(stdout)
  local ok, data = pcall(vim.json.decode, stdout)
  if not ok then
    return nil
  end
  -- Support different JSON structures across task versions
  return data.tasks or data
end

--- Create an Overseer task definition from go-task metadata
---
--- Transforms go-task metadata into an Overseer-compatible task definition,
--- configuring command execution, arguments, and output handling.
---
--- @param task table Task metadata containing name and optional description
--- @param dir string Working directory path for task execution
--- @return table Overseer task definition with builder function and configuration
local function create_task_definition(task, dir)
  return {
    name = "Task: " .. task.name,
    desc = task.desc or "",
    builder = function(params)
      local args = { task.name }

      -- Parse and append additional arguments if provided
      -- Splits space-separated arguments (e.g., "-v --force" -> {"-v", "--force"})
      -- Note: For quoted arguments (e.g., -m "hello world"), consider using a more
      -- sophisticated parser. For most flags, vim.split is sufficient.
      if params.args and params.args ~= "" then
        local parsed_args = vim.split(params.args, "%s+", { trimempty = true })
        vim.list_extend(args, parsed_args)
      end

      return {
        cmd = { CMD_TASK },
        args = args,
        cwd = dir,
        components = {
          -- Open output window and focus on completion
          { "on_output_summarize", max_lines = 10 },
          { "open_output", on_complete = "always", focus = true },
          "default",
        },
      }
    end,
    tags = { "TASK" },
    params = {
      args = {
        type = "string",
        name = "Arguments",
        desc = "Extra arguments (e.g., -f, --watch, or -- -v)",
        optional = true,
        default = "",
      },
    },
    priority = 50,
  }
end

return {
  --- Only activate when a Taskfile exists in the current directory
  condition = {
    callback = function(opts)
      return has_taskfile(opts.dir)
    end,
  },

  --- Generate overseer tasks from go-task definitions
  --- @param opts table Options containing directory information
  --- @param cb function Callback to return generated tasks
  generator = function(opts, cb)
    vim.system({ CMD_TASK, "--list-all", "--json" }, { cwd = opts.dir, text = true }, function(obj)
      vim.schedule(function()
        -- Handle command failure
        if obj.code ~= 0 then
          cb({})
          return
        end

        -- Parse JSON output
        local tasks = parse_tasks(obj.stdout)
        if not tasks then
          cb({})
          return
        end

        -- Generate overseer task definitions
        local task_definitions = {}
        for _, task in ipairs(tasks) do
          if not task.internal then
            table.insert(task_definitions, create_task_definition(task, opts.dir))
          end
        end

        cb(task_definitions)
      end)
    end)
  end,
}
