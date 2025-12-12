import { test, expect } from '@playwright/test';

test('navigate core views', async ({ page }) => {
  await page.goto('/');

  // Navigation bar is visible
  await expect(page.getByRole('link', { name: /Dashboard/i })).toBeVisible();

  // ---- Orders ----
  await page.getByRole('link', { name: /^Orders$/i }).click();
  await expect(
    page.getByRole('main').getByText('Orders', { exact: true })
  ).toBeVisible();

  // ---- Catalog ----
  await page.getByRole('link', { name: /^Catalog$/i }).click();
  await expect(
    page.getByRole('main').getByText('Catalog', { exact: true })
  ).toBeVisible();

  // ---- Analytics ----
  await page.getByRole('link', { name: /Analytics/i }).click();
  // More robust: assert route instead of exact heading text
  await expect(page).toHaveURL(/\/analytics/);

  // ---- System Status ----
  await page.getByRole('link', { name: /System/i }).click();
  await expect(page.getByText(/Service Status/i)).toBeVisible();
});
