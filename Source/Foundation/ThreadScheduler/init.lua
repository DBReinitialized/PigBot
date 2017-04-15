--[[
  Dream Foundations
  Foundations/ThreadScheduler/init.lua ver 0.1.0 indev
  Main script for loading the ROBLOX-like ThreadScheduler package

  Changelog:
    [4142017a]
      - Initial setup of code
]]

local foundation = _G.foundations("GVp6kjhNUK")

local threadScheduler = {}
local _private = foundation._private.internals.getPrivateSpace("threadScheduler")

_private.queuedTasks = {}
_private.internals = {}
_private.schedulerRunning = false
_private.schedulerThread = nil

function _private.internals.scheduleTask(taskData)
  assert(type(taskData) == "table", "bad argument #1 (table expected, got ".. type(taskData) ..")")

  _private.queuedTasks[#_private.queuedTasks + 1] = taskData
  table.sort(
    _private.queuedTasks,
    function(taskA, taskB)
      if (taskA.priority < taskB.priority) then
        return true

      else
        return taskA.resumeAt < taskB.resumeAt

      end
    end
  )
end

-- main api
function threadScheduler.suspend(totalTime)
  totalTime = type(totalTime) == "number" and totalTime or 0

  _private.internals.scheduleTask(
    {
      thread = coroutine.running(),
      resumeAt = os.time() + totalTime,
      priority = 0
    }
  )

  return coroutine.yield()
end

function threadScheduler.spawn(callback, ...)
  assert(type(callback) == "function", "bad argument #1 (function expected, got ".. type(callback) ..")")

  _private.internals.scheduleTask(
    {
      thread = coroutine.create(callback),
      resumeAt = os.time(),
      priority = 1,
      packed = ...
    }
  )
end

function threadScheduler:startScheduler()
  assert(self == threadScheduler, "this function must be called using \":\" on it's originating table.")

  local schedulerThread = _private.schedulerThread
  local _, status = pcall(coroutine.status, schedulerThread)

  if (type(schedulerThread) ~= "coroutine" or status == "dead") then
    schedulerThread = coroutine.create(
      function()
        local luaPlatform, now, removedThread = foundation._private.luaPlatform:sub(1, 3), os.time()
        local runService do
          if (luaPlatform == "RBX") then
            runService = game:GetService("RunService")
          end
        end

        while true do
          if (not _private.schedulerRunning) then
            coroutine.yield()
          end

          -- print(#_private.queuedTasks, _private.runningScheduler, now, _private.queuedTasks[1].resumeAt, _private.queuedTasks[1].priority, math.random())

          now = os.time()
          if (#_private.queuedTasks > 0) then
            if (_private.queuedTasks[1].resumeAt <= now) then
              removedThread = table.remove(_private.queuedTasks, 1)

              local ran, errorMsg = coroutine.resume(removedThread.thread, removedThread.packed)
              if not (ran) then
                error("\n\n--[[\n\tfoundations.threadScheduler._private.schedulerThread FATAL:\n\tmanaged thread ran into a fatal error!\n\n".. errorMsg .."\n\n--]]\n\n")
              end
            end
          -- else
          --   for key, value in next, _private.queuedTasks do
          --     print(key, value, value.priority, value.resumeAt)
          --   end
          end

          if (luaPlatform == "RBX") then
            runService.Stepped:wait()
          end
        end

        print("foundation.threadScheduler._private.schedulerThread FATAL:scheduler has ended")
      end
    )

    _private.schedulerThread = schedulerThread
    status = coroutine.status(schedulerThread)
  end

  if (status == "suspended") then
    print("foundation.threadScheduler:startScheduler() INFO: scheduler is now starting")

    _private.schedulerRunning = true
    print(coroutine.resume(schedulerThread))
  else
    error("foundation.threadScheduler:startScheduler() FATAL: cannot resume not suspended scheduler!", 2)

  end
end

function threadScheduler:suspendScheduler()
  assert(self == threadScheduler, "this function must be called using \":\" on it's originating table.")

  local thread = _private.schedulerThread
  local _, status = pcall(coroutine.status, thread)

  if not (status == "running") then
    error("foundation.threadScheduler:suspendScheduler() FATAL: cannot suspend not running scheduler!", 2)

  else
    _private.schedulerRunning = false

    print("foundation.threadScheduler:suspendScheduler() INFO: scheduler is now suspending")
  end
end


-- add threadScheduler to foundation
foundation.threadScheduler = threadScheduler

-- roblox module compatibility
if (foundation._private.luaPlatform:sub(1, 3) == "RBX") then
  return true
end