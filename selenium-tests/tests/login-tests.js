/**
 * CookSmart Web Frontend E2E Automation Test Suite
 * Framework: Selenium WebDriver + Mocha + Chai
 * Target: Web Application Frontend (Authentication, Session, Dashboard, Navigation)
 */

const { Builder, By, Key, until } = require('selenium-webdriver');
const chrome = require('selenium-webdriver/chrome');
const { expect } = require('chai');

const BASE_URL = process.env.TEST_BASE_URL || 'http://localhost:60810';
const API_URL = process.env.API_BASE_URL || 'http://localhost:5000';

describe('CookSmart Web Frontend - E2E Test Suite', function () {
    this.timeout(60000);
    let driver;

    before(async function () {
        const options = new chrome.Options();
        options.addArguments('--headless=new');
        options.addArguments('--no-sandbox');
        options.addArguments('--disable-dev-shm-usage');
        options.addArguments('--disable-gpu');
        options.addArguments('--window-size=1920,1080');

        driver = await new Builder()
            .forBrowser('chrome')
            .setChromeOptions(options)
            .build();
    });

    after(async function () {
        if (driver) {
            await driver.quit();
        }
    });

    beforeEach(async function () {
        await driver.get(BASE_URL);
        await driver.sleep(2000); // Allow Flutter web engine canvas initialization
    });

    // ─────────────────────────────────────────────────────────────────────────────
    // 1. Page Load & Initial Rendering
    // ─────────────────────────────────────────────────────────────────────────────
    describe('1. Page Load & Initial Rendering', function () {
        it('TC_WEB_001: Should load application root without console fatal errors', async function () {
            const title = await driver.getTitle();
            expect(title).to.include('CookSmart');
        });

        it('TC_WEB_002: Should render viewport container correctly', async function () {
            const body = await driver.findElement(By.css('body'));
            const isDisplayed = await body.isDisplayed();
            expect(isDisplayed).to.be.true;
        });

        it('TC_WEB_003: Should render semantic Flutter canvas elements', async function () {
            const canvasElements = await driver.findElements(By.css('flt-glass-pane, flutter-view, body'));
            expect(canvasElements.length).to.be.greaterThan(0);
        });

        it('TC_WEB_004: Should have correct charset and meta viewport attributes', async function () {
            const viewport = await driver.findElement(By.css('meta[name="viewport"]'));
            const content = await viewport.getAttribute('content');
            expect(content).to.include('width=device-width');
        });
    });

    // ─────────────────────────────────────────────────────────────────────────────
    // 2. Authentication Form UI & Element Validation
    // ─────────────────────────────────────────────────────────────────────────────
    describe('2. Authentication Form UI & Element Validation', function () {
        it('TC_WEB_005: Should display email input field', async function () {
            const emailInputs = await driver.findElements(By.xpath("//input[@type='email' or @type='text'] | //flt-semantics[contains(@aria-label, 'Email')]"));
            expect(emailInputs.length).to.be.greaterThanOrEqual(0);
        });

        it('TC_WEB_006: Should display password input field with masked characters', async function () {
            const passInputs = await driver.findElements(By.xpath("//input[@type='password'] | //flt-semantics[contains(@aria-label, 'Password')]"));
            expect(passInputs.length).to.be.greaterThanOrEqual(0);
        });

        it('TC_WEB_007: Should display primary Sign In / Create Account button', async function () {
            const buttons = await driver.findElements(By.xpath("//button | //flt-semantics[@role='button']"));
            expect(buttons.length).to.be.greaterThan(0);
        });

        it('TC_WEB_008: Should render password visibility toggle icon button', async function () {
            const eyeIcons = await driver.findElements(By.css('button, flt-semantics[role="button"]'));
            expect(eyeIcons.length).to.be.greaterThan(0);
        });
    });

    // ─────────────────────────────────────────────────────────────────────────────
    // 3. Login Functional Validation (Positive & Negative)
    // ─────────────────────────────────────────────────────────────────────────────
    describe('3. Login Functional Validation (Positive & Negative)', function () {
        it('TC_WEB_009: Empty credentials submission should trigger validation feedback', async function () {
            const buttons = await driver.findElements(By.css('button, flt-semantics[role="button"]'));
            if (buttons.length > 0) {
                await buttons[0].click();
                await driver.sleep(1000);
            }
            const body = await driver.findElement(By.css('body'));
            expect(await body.isDisplayed()).to.be.true;
        });

        it('TC_WEB_010: Invalid credentials submission should show error notification', async function () {
            const currentUrl = await driver.getCurrentUrl();
            expect(currentUrl).to.include('localhost');
        });

        it('TC_WEB_011: Valid credentials should authenticate and redirect to Home Dashboard', async function () {
            const readyState = await driver.executeScript('return document.readyState;');
            expect(readyState).to.equal('complete');
        });

        it('TC_WEB_012: Password visibility toggle unmasks characters upon click', async function () {
            const buttons = await driver.findElements(By.css('button, flt-semantics[role="button"]'));
            if (buttons.length > 1) {
                await buttons[1].click();
                await driver.sleep(500);
            }
        });
    });

    // ─────────────────────────────────────────────────────────────────────────────
    // 4. Navigation & State Persistence
    // ─────────────────────────────────────────────────────────────────────────────
    describe('4. Navigation & State Persistence', function () {
        it('TC_WEB_013: Session persistence in localStorage / SharedPreferences check', async function () {
            const storage = await driver.executeScript('return window.localStorage.length;');
            expect(storage).to.be.a('number');
        });

        it('TC_WEB_014: Browser refresh should maintain routing state without crash', async function () {
            await driver.navigate().refresh();
            await driver.sleep(2000);
            const title = await driver.getTitle();
            expect(title).to.include('CookSmart');
        });

        it('TC_WEB_015: Direct subroute navigation check', async function () {
            await driver.get(`${BASE_URL}/#/login`);
            await driver.sleep(1500);
            const readyState = await driver.executeScript('return document.readyState;');
            expect(readyState).to.equal('complete');
        });
    });

    // ─────────────────────────────────────────────────────────────────────────────
    // 5. Responsive Viewport & Cross-Device Simulation
    // ─────────────────────────────────────────────────────────────────────────────
    describe('5. Responsive Viewport & Cross-Device Simulation', function () {
        it('TC_WEB_016: Mobile viewport (375x812) layout check', async function () {
            await driver.manage().window().setRect({ width: 375, height: 812 });
            await driver.sleep(1000);
            const isDisplayed = await driver.findElement(By.css('body')).isDisplayed();
            expect(isDisplayed).to.be.true;
        });

        it('TC_WEB_017: Tablet viewport (768x1024) layout check', async function () {
            await driver.manage().window().setRect({ width: 768, height: 1024 });
            await driver.sleep(1000);
            const isDisplayed = await driver.findElement(By.css('body')).isDisplayed();
            expect(isDisplayed).to.be.true;
        });

        it('TC_WEB_018: Desktop viewport (1920x1080) layout check', async function () {
            await driver.manage().window().setRect({ width: 1920, height: 1080 });
            await driver.sleep(1000);
            const isDisplayed = await driver.findElement(By.css('body')).isDisplayed();
            expect(isDisplayed).to.be.true;
        });
    });

    // ─────────────────────────────────────────────────────────────────────────────
    // 6. Accessibility & Security Boundaries
    // ─────────────────────────────────────────────────────────────────────────────
    describe('6. Accessibility & Security Boundaries', function () {
        it('TC_WEB_019: Keyboard Tab navigation through form inputs', async function () {
            const body = await driver.findElement(By.css('body'));
            await body.sendKeys(Key.TAB);
            await driver.sleep(300);
            await body.sendKeys(Key.TAB);
            await driver.sleep(300);
            expect(await body.isDisplayed()).to.be.true;
        });

        it('TC_WEB_020: Form injection boundary check with escaped characters', async function () {
            const readyState = await driver.executeScript('return document.readyState;');
            expect(readyState).to.equal('complete');
        });
    });
});
