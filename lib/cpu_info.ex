defmodule CpuInfo do
  @moduledoc """

  **CpuInfo:** get CPU information, including a type, number of processors, number of physical cores and logical threads of a processor, and status of simultaneous multi-threads (hyper-threading).

  """

  defp os_type do
    case :os.type() do
      {:unix, :linux} -> :linux
      {:unix, :darwin} -> :macos
      {:unix, :freebsd} -> :freebsd
      {:win32, _} -> :windows
      _ -> :other
    end
  end

  @doc """
    Show all profile information on CPU and the system.
  """
  def all_profile do
    os_type()
    |> cpu_type_sub()
    |> Map.merge(%{
      otp_version: :erlang.system_info(:otp_release) |> List.to_string() |> String.to_integer(),
      elixir_version: System.version()
    })
  end

  defp confirm_executable(command) do
    if is_nil(System.find_executable(command)) do
      raise RuntimeError, message: "#{command} isn't found."
    end
  end

  defp cpu_type_sub(:other) do
    %{
      kernel_release: :unknown,
      kernel_version: :unknown,
      system_version: :unknown,
      cpu_type: :unknown,
      os_type: :other,
      cpu_model: :unknown,
      cpu_models: :unknown,
      num_of_processors: :unknown,
      num_of_cores_of_a_processor: :unknown,
      total_num_of_cores: :unknown,
      num_of_threads_of_a_processor: :unknown,
      total_num_of_threads: System.schedulers_online(),
      hyper_threading: :unknown
    }
  end

  defp cpu_type_sub(:windows) do
    %{
      kernel_release: :unknown,
      kernel_version: :unknown,
      system_version: :unknown,
      cpu_type: :unknown,
      os_type: :windows,
      cpu_model: :unknown,
      cpu_models: :unknown,
      num_of_processors: :unknown,
      num_of_cores_of_a_processor: :unknown,
      total_num_of_cores: :unknown,
      num_of_threads_of_a_processor: :unknown,
      total_num_of_threads: System.schedulers_online(),
      hyper_threading: :unknown
    }
  end

  defp cpu_type_sub(:linux) do
    confirm_executable("cat")
    confirm_executable("grep")
    confirm_executable("sort")
    confirm_executable("wc")
    confirm_executable("uname")

    kernel_release =
      case System.cmd("uname", ["-r"]) do
        {result, 0} -> result |> String.trim()
        _ -> raise RuntimeError, message: "uname don't work."
      end

    system_version =
      case System.cmd("cat", ["/etc/issue"]) do
        {result, 0} -> result |> String.trim()
        _ -> ""
      end

    kernel_version =
      case System.cmd("uname", ["-v"]) do
        {result, 0} -> result |> String.trim()
        _ -> raise RuntimeError, message: "uname don't work."
      end

    cpu_type =
      case System.cmd("uname", ["-m"]) do
        {result, 0} -> result |> String.trim()
        _ -> raise RuntimeError, message: "uname don't work."
      end

    cpu_models =
      :os.cmd('grep model.name /proc/cpuinfo | sort -u')
      |> List.to_string()
      |> String.split("\n")
      |> Enum.map(&String.trim(&1))
      |> Enum.reject(&(String.length(&1) == 0))
      |> Enum.map(&String.split(&1))
      |> Enum.map(&Enum.slice(&1, 3..-1))
      |> Enum.map(&Enum.join(&1, " "))

    cpu_model = hd(cpu_models)

    num_of_processors =
      :os.cmd('grep physical.id /proc/cpuinfo | sort -u | wc -l')
      |> List.to_string()
      |> String.trim()
      |> String.to_integer()

    num_of_cores_of_a_processor =
      :os.cmd('grep cpu.cores /proc/cpuinfo | sort -u')
      |> List.to_string()
      |> String.trim()
      |> match_to_integer()

    total_num_of_cores = num_of_cores_of_a_processor * num_of_processors

    total_num_of_threads =
      :os.cmd('grep processor /proc/cpuinfo | wc -l')
      |> List.to_string()
      |> String.trim()
      |> String.to_integer()

    num_of_threads_of_a_processor = div(total_num_of_threads, num_of_processors)

    ht =
      if total_num_of_cores < total_num_of_threads do
        :enabled
      else
        :disabled
      end

    %{
      kernel_release: kernel_release,
      kernel_version: kernel_version,
      system_version: system_version,
      cpu_type: cpu_type,
      os_type: :linux,
      cpu_model: cpu_model,
      cpu_models: cpu_models,
      num_of_processors: num_of_processors,
      num_of_cores_of_a_processor: num_of_cores_of_a_processor,
      total_num_of_cores: total_num_of_cores,
      num_of_threads_of_a_processor: num_of_threads_of_a_processor,
      total_num_of_threads: total_num_of_threads,
      hyper_threading: ht
    }
  end

  defp cpu_type_sub(:freebsd) do
    confirm_executable("uname")
    confirm_executable("sysctl")

    kernel_release =
      case System.cmd("uname", ["-r"]) do
        {result, 0} -> result |> String.trim()
        _ -> raise RuntimeError, message: "uname don't work."
      end

    system_version =
      case System.cmd("uname", ["-r"]) do
        {result, 0} -> result |> String.trim()
        _ -> ""
      end

    kernel_version =
      case System.cmd("uname", ["-r"]) do
        {result, 0} -> result |> String.trim()
        _ -> raise RuntimeError, message: "uname don't work."
      end

    cpu_type =
      case System.cmd("uname", ["-m"]) do
        {result, 0} -> result |> String.trim()
        _ -> raise RuntimeError, message: "uname don't work."
      end

    cpu_model =
      case System.cmd("sysctl", ["-n", "hw.model"]) do
        {result, 0} -> result |> String.trim()
        _ -> raise RuntimeError, message: "sysctl don't work."
      end

    cpu_models = [cpu_model]

    total_num_of_cores =
      case System.cmd("sysctl", ["-n", "kern.smp.cores"]) do
        {result, 0} -> result |> String.trim() |> String.to_integer()
        _ -> raise RuntimeError, message: "sysctl don't work."
      end

    total_num_of_threads =
      case System.cmd("sysctl", ["-n", "kern.smp.cpus"]) do
        {result, 0} -> result |> String.trim() |> String.to_integer()
        _ -> raise RuntimeError, message: "sysctl don't work."
      end

    ht =
      case System.cmd("sysctl", ["-n", "machdep.hyperthreading_allowed"]) do
        {"1\n", 0} -> :enabled
        {"0\n", 0} -> :disabled
        _ -> raise RuntimeError, message: "sysctl don't work."
      end

    %{
      kernel_release: kernel_release,
      kernel_version: kernel_version,
      system_version: system_version,
      cpu_type: cpu_type,
      os_type: :freebsd,
      cpu_model: cpu_model,
      cpu_models: cpu_models,
      num_of_processors: :unknown,
      num_of_cores_of_a_processor: :unknown,
      total_num_of_cores: total_num_of_cores,
      num_of_threads_of_a_processor: :unknown,
      total_num_of_threads: total_num_of_threads,
      hyper_threading: ht
    }
  end

  defp cpu_type_sub(:macos) do
    confirm_executable("uname")
    confirm_executable("system_profiler")

    kernel_release =
      case System.cmd("uname", ["-r"]) do
        {result, 0} -> result |> String.trim()
        _ -> raise RuntimeError, message: "uname don't work."
      end

    cpu_type =
      case System.cmd("uname", ["-m"]) do
        {result, 0} -> result |> String.trim()
        _ -> raise RuntimeError, message: "uname don't work."
      end

    %{
      kernel_release: kernel_release,
      cpu_type: cpu_type
    }
    |> Map.merge(
      case System.cmd("system_profiler", ["SPSoftwareDataType"]) do
        {result, 0} -> result |> detect_system_and_kernel_version()
        _ -> raise RuntimeError, message: "uname don't work."
      end
    )
    |> Map.merge(
      case System.cmd("system_profiler", ["SPHardwareDataType"]) do
        {result, 0} -> result |> parse_macos
        _ -> raise RuntimeError, message: "system_profiler don't work."
      end
    )
  end

  defp detect_system_and_kernel_version(message) do
    trimmed_message = message |> split_trim

    %{
      kernel_version:
        trimmed_message
        |> Enum.filter(&String.match?(&1, ~r/Kernel Version/))
        |> hd
        |> String.split()
        |> Enum.slice(2..-1)
        |> Enum.join(" "),
      system_version:
        trimmed_message
        |> Enum.filter(&String.match?(&1, ~r/System Version/))
        |> hd
        |> String.split()
        |> Enum.slice(2..-1)
        |> Enum.join(" ")
    }
  end

  defp parse_macos(message) do
    trimmed_message = message |> split_trim

    cpu_model =
      Enum.filter(trimmed_message, &String.match?(&1, ~r/Processor Name/))
      |> hd
      |> String.split()
      |> Enum.slice(2..-1)
      |> Enum.join(" ")

    cpu_models = [cpu_model]

    num_of_processors =
      Enum.filter(trimmed_message, &String.match?(&1, ~r/Number of Processors/))
      |> hd
      |> match_to_integer()

    total_num_of_cores =
      Enum.filter(trimmed_message, &String.match?(&1, ~r/Total Number of Cores/))
      |> hd
      |> match_to_integer()

    num_of_cores_of_a_processor = div(total_num_of_cores, num_of_processors)

    m_ht = Enum.filter(trimmed_message, &String.match?(&1, ~r/Hyper-Threading Technology/))

    ht =
      if length(m_ht) > 0 and String.match?(hd(m_ht), ~r/Enabled/) do
        :enabled
      else
        :disabled
      end

    total_num_of_threads =
      total_num_of_cores *
        case ht do
          :enabled -> 2
          :disabled -> 1
        end

    num_of_threads_of_a_processor = div(total_num_of_threads, num_of_processors)

    %{
      os_type: :macos,
      cpu_model: cpu_model,
      cpu_models: cpu_models,
      num_of_processors: num_of_processors,
      num_of_cores_of_a_processor: num_of_cores_of_a_processor,
      total_num_of_cores: total_num_of_cores,
      num_of_threads_of_a_processor: num_of_threads_of_a_processor,
      total_num_of_threads: total_num_of_threads,
      hyper_threading: ht
    }
  end

  defp split_trim(message) do
    message |> String.split("\n") |> Enum.map(&String.trim(&1))
  end

  defp match_to_integer(message) do
    Regex.run(~r/[0-9]+/, message) |> hd |> String.to_integer()
  end
end
