// Prepended to upstream's smoke.test.ts to reuse its installed-app fixtures.
import { createServer, type Server } from "node:http";

const testLainbowEndpoint = "http://127.0.0.1:18888";
let lainbowServer: Server | undefined;

test.beforeAll(async () => {
	if (process.env.VITE_LAINBOW_ENDPOINT !== testLainbowEndpoint) return;
	lainbowServer = createServer((request, response) => {
		if (request.url !== "/api/v1/stats") {
			response.writeHead(404).end();
			return;
		}
		response.writeHead(200, { "Content-Type": "application/json" });
		response.end(
			JSON.stringify({
				total_songs: 7,
				songs_with_acoustic_features: 0,
				songs_with_clap: 0,
				songs_with_mert: 0,
				songs_with_muq: 6,
				songs_with_muq_mulan: 5,
				pending_tasks: 0,
				running_tasks: 0,
			}),
		);
	});
	await new Promise<void>((resolve, reject) => {
		lainbowServer?.once("error", reject);
		lainbowServer?.listen(18888, "127.0.0.1", resolve);
	});
});

test.afterAll(async () => {
	if (lainbowServer === undefined) return;
	const server = lainbowServer;
	await new Promise<void>((resolve, reject) => {
		server.close((error) => (error ? reject(error) : resolve()));
		server.closeAllConnections();
	});
});

test("advanced search follows the configured endpoint", async () => {
	const endpoint = process.env.VITE_LAINBOW_ENDPOINT;
	test.skip(
		endpoint !== undefined && endpoint !== testLainbowEndpoint,
		"External Lainbow services are unavailable in the build sandbox",
	);
	// firstWindow() can resolve before the initial document has navigated.
	await expect(page.locator("#root")).toBeVisible();
	await page.waitForLoadState("load");
	await page.goto("sola://app/home/settings/device");
	await expect(page.getByRole("heading", { name: "This Device", exact: true }))
		.toBeVisible();
	const advancedSearch = page.getByRole("heading", {
		name: "Advanced Search",
		exact: true,
	});
	if (endpoint === undefined) {
		await expect(advancedSearch).toHaveCount(0);
		await expect(page.getByText("Text-to-Music", { exact: true })).toHaveCount(0);
		return;
	}
	await expect(advancedSearch).toBeVisible();
	await expect(page.getByRole("button", { name: "Scan Library", exact: true }))
		.toBeVisible();
	await expect(page.getByRole("button", { name: "Analyze", exact: true }))
		.toBeVisible();
	await expect(page.getByRole("cell", { name: "6", exact: true })).toBeVisible();
	await expect(page.getByRole("cell", { name: "5", exact: true })).toBeVisible();
	await expect(page.getByText("Text-to-Music", { exact: true })).toBeVisible();
});
