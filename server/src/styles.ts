import { logger } from "./logger";

export async function loadStyleMap(filePath: string | null): Promise<string | null> {
  if (!filePath) {
    logger.debug("No style map file specified, using mammoth defaults");
    return null;
  }

  try {
    const file = Bun.file(filePath);
    const exists = await file.exists();
    if (!exists) {
      logger.warn(`Style map file not found: ${filePath}`);
      return null;
    }
    const content = await file.text();
    logger.debug(`Loaded style map from: ${filePath}`);
    return content;
  } catch (error) {
    logger.warn(`Failed to load style map from ${filePath}: ${error}`);
    return null;
  }
}
