type LogLevel = "debug" | "info" | "warn" | "error";

interface LoggerConfig {
  level: LogLevel;
}

const LEVEL_PRIORITY: Record<LogLevel, number> = {
  debug: 0,
  info: 1,
  warn: 2,
  error: 3,
};

class Logger {
  private level: LogLevel;

  constructor(level: LogLevel = "warn") {
    this.level = level;
  }

  setLevel(level: LogLevel): void {
    this.level = level;
  }

  private shouldLog(level: LogLevel): boolean {
    return LEVEL_PRIORITY[level] >= LEVEL_PRIORITY[this.level];
  }

  private formatMessage(level: LogLevel, message: string): string {
    const timestamp = new Date().toISOString();
    return `[${timestamp}] [${level.toUpperCase()}] ${message}`;
  }

  debug(message: string): void {
    if (this.shouldLog("debug")) {
      console.log(this.formatMessage("debug", message));
    }
  }

  info(message: string): void {
    if (this.shouldLog("info")) {
      console.log(this.formatMessage("info", message));
    }
  }

  warn(message: string): void {
    if (this.shouldLog("warn")) {
      console.warn(this.formatMessage("warn", message));
    }
  }

  error(message: string): void {
    if (this.shouldLog("error")) {
      console.error(this.formatMessage("error", message));
    }
  }
}

export const logger = new Logger(
  (process.env.LOG_LEVEL as LogLevel) || "warn"
);

export function createLogger(level: LogLevel): Logger {
  return new Logger(level);
}
