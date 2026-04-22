import { logger } from "./logger";
import mammoth from "mammoth";
import { loadStyleMap } from "./styles";
import { mkdir, unlink } from "node:fs/promises";

export interface ConverterConfig {
  pandocBin: string;
  referenceDoc: string | null;
  outputDir: string;
  extraPandocArgs: string[];
  styleMapFile: string | null;
}

export type ConversionResult =
  | { ok: true; html: string; durationMs: number }
  | { ok: false; error: string };

async function runPandoc(
  inputFile: string,
  outputFile: string,
  config: ConverterConfig,
): Promise<{ ok: true } | { ok: false; error: string }> {
  const args = [
    inputFile,
    "-o", outputFile,
    "--standalone",
  ];

  if (config.referenceDoc) {
    args.push("--reference-doc=" + config.referenceDoc);
  }

  if (config.extraPandocArgs.length > 0) {
    args.push(...config.extraPandocArgs);
  }

  logger.debug(`Running pandoc: ${config.pandocBin} ${args.join(" ")}`);

  const startTime = Date.now();

  const proc = Bun.spawn([config.pandocBin, ...args], {
    stdout: "pipe",
    stderr: "pipe",
  });
  const [stdout, stderr] = await Promise.all([
    new Response(proc.stdout).text(),
    new Response(proc.stderr).text(),
  ]);
  const outputText = stdout + stderr;
  const exitCode = await proc.exited;

  if (exitCode !== 0) {
    logger.error(`Pandoc failed with exit code ${exitCode}: ${outputText}`);
    return { ok: false, error: `Pandoc failed: ${outputText}` };
  }

  logger.debug(`Pandoc completed in ${Date.now() - startTime}ms`);
  return { ok: true };
}

async function runMammoth(
  docxFile: string,
  styleMap: string | null,
): Promise<{ ok: true; html: string } | { ok: false; error: string }> {
  try {
    const options: Record<string, unknown> = {};

    if (styleMap) {
      options.styleMap = styleMap;
    }

    const result = await mammoth.convertToHtml({ path: docxFile }, options);

    if (result.messages && result.messages.length > 0) {
      const warnings = result.messages.map((m) => m.message).join(", ");
      logger.warn(`Mammoth warnings: ${warnings}`);
    }

    return { ok: true, html: result.value };
  } catch (error) {
    const errMsg = error instanceof Error ? error.message : String(error);
    logger.error(`Mammoth failed: ${errMsg}`);
    return { ok: false, error: `Mammoth conversion failed: ${errMsg}` };
  }
}

async function cleanup(docxFile: string): Promise<void> {
  try {
    await unlink(docxFile);
    logger.debug(`Cleaned up: ${docxFile}`);
  } catch (error) {
    logger.warn(`Failed to cleanup ${docxFile}: ${error}`);
  }
}

export async function convert(
  file: string,
  config: ConverterConfig,
): Promise<ConversionResult> {
  const startTime = Date.now();

  const uuid = crypto.randomUUID();
  const docxFile = `${config.outputDir}/${uuid}.docx`;

  logger.info(`Converting: ${file}`);

  await mkdir(config.outputDir, { recursive: true });

  const pandocResult = await runPandoc(file, docxFile, config);
  if (!pandocResult.ok) {
    return { ok: false, error: pandocResult.error };
  }

  const styleMap = await loadStyleMap(config.styleMapFile);
  const mammothResult = await runMammoth(docxFile, styleMap);

  await cleanup(docxFile);

  if (!mammothResult.ok) {
    return { ok: false, error: mammothResult.error };
  }

  const durationMs = Date.now() - startTime;
  logger.info(`Conversion completed in ${durationMs}ms`);

  return {
    ok: true,
    html: mammothResult.html,
    durationMs,
  };
}
