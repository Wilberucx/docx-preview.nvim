import { logger } from "./logger";
import { createServer, broadcast, type ServerConfig } from "./server";
import { convert, type ConverterConfig } from "./converter";
import { mkdirSync, existsSync } from "fs";

function parseArgs(): Partial<ServerConfig> {
  const args = process.argv.slice(2);
  const config: Partial<ServerConfig> = {};

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    const next = args[i + 1];

    switch (arg) {
      case "--port":
        config.port = parseInt(next, 10);
        i++;
        break;
      case "--host":
        config.host = next;
        i++;
        break;
      case "--pandoc-bin":
        config.pandocBin = next;
        i++;
        break;
      case "--output-dir":
        config.outputDir = next;
        i++;
        break;
      case "--reference-doc":
        config.referenceDoc = next;
        i++;
        break;
      case "--extra-pandoc-args":
        try {
          config.extraPandocArgs = JSON.parse(next);
        } catch {
          config.extraPandocArgs = [];
        }
        i++;
        break;
      case "--style-map-file":
        config.styleMapFile = next;
        i++;
        break;
      case "--log-level":
        logger.setLevel(next as "debug" | "info" | "warn" | "error");
        i++;
        break;
    }
  }

  return config;
}

type Command =
  | { cmd: "convert"; file: string }
  | { cmd: "print" }
  | { cmd: "shutdown" };

async function handleCommand(cmd: Command, config: ServerConfig): Promise<void> {
  switch (cmd.cmd) {
    case "convert": {
      await handleConvert(cmd.file, config);
      console.log(
        JSON.stringify({
          status: "converted",
          file: cmd.file,
        })
      );
      break;
    }

    case "print": {
      broadcast({ type: "print" });
      console.log(JSON.stringify({ status: "print_sent" }));
      break;
    }

    case "shutdown": {
      console.log(JSON.stringify({ status: "shutting_down" }));
      process.exit(0);
      break;
    }
  }
}

async function handleConvert(file: string, config: ServerConfig): Promise<void> {
  const converterConfig: ConverterConfig = {
    pandocBin: config.pandocBin,
    referenceDoc: config.referenceDoc,
    outputDir: config.outputDir,
    extraPandocArgs: config.extraPandocArgs,
    styleMapFile: config.styleMapFile,
  };

  const result = await convert(file, converterConfig);

  if (result.ok) {
    broadcast({ type: "update", html: result.html });
    logger.info(`Converted ${file} in ${result.durationMs}ms`);
  } else {
    broadcast({ type: "error", message: result.error });
    logger.error(`Conversion failed: ${result.error}`);
  }
}

async function main() {
  const cliConfig = parseArgs();

  const config: ServerConfig = {
    port: cliConfig.port || 8765,
    host: cliConfig.host || "127.0.0.1",
    pandocBin: cliConfig.pandocBin || "pandoc",
    referenceDoc: cliConfig.referenceDoc || null,
    outputDir: cliConfig.outputDir || (() => { throw new Error("--output-dir is required"); })(),
    extraPandocArgs: cliConfig.extraPandocArgs || [],
    styleMapFile: cliConfig.styleMapFile || null,
  };

  if (!existsSync(config.outputDir)) {
    mkdirSync(config.outputDir, { recursive: true });
    logger.debug(`Created output directory: ${config.outputDir}`);
  }

  const server = createServer(config);

  const url = `http://${config.host}:${config.port}`;
  logger.info(`Server started on ${url}`);

  console.log(
    JSON.stringify({
      status: "ready",
      url: url,
    })
  );

  const reader = Bun.stdin.stream().getReader();
  const decoder = new TextDecoder();
  let buffer = "";

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;

    buffer += decoder.decode(value, { stream: true });
    const lines = buffer.split("\n");
    buffer = lines.pop() || "";

    for (const line of lines) {
      if (line.trim()) {
        try {
          const cmd = JSON.parse(line) as Command;
          await handleCommand(cmd, config);
        } catch (error) {
          logger.error(`Invalid command: ${line}`);
        }
      }
    }
  }
}

main().catch((error) => {
  logger.error(`Fatal error: ${error}`);
  process.exit(1);
});
