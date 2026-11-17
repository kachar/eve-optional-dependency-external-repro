import { NextResponse } from "next/server.js";
import { defineTool } from "eve/tools";
import { z } from "zod";

export default defineTool({
  description: "Return a JSON body.",
  inputSchema: z.object({}),
  async execute() {
    return NextResponse.json({ ok: true }).status;
  },
});
