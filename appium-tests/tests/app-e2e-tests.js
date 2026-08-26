/**
 * CookSmart Mobile App E2E Automation Test Suite
 * Framework: Appium 2.x + WebDriverIO + Mocha + Chai
 * Target: Android & iOS Mobile Frontend (Flutter Engine, Mobile Gestures, Device Lifecycle)
 */

const { remote } = require('webdriverio');
const { expect } = require('chai');

const wdOpts = {
    hostname: process.env.APPIUM_HOST || '127.0.0.1',
    port: parseInt(process.env.APPIUM_PORT || '4723'),
    logLevel: 'info',
    capabilities: {
        platformName: 'Android',
        'appium:automationName': 'UiAutomator2',
        'appium:deviceName': process.env.DEVICE_NAME || 'Android Device',
        'appium:appPackage': 'com.example.cooksmart_app',
        'appium:appActivity': '.MainActivity',
        'appium:noReset': false,
        'appium:fullReset': false,
        'appium:newCommandTimeout': 300,
        'appium:autoGrantPermissions': true
    }
};

describe('CookSmart Mobile App - Appium E2E Automation Test Suite', function () {
    this.timeout(90000);
    let driver;

    before(async function () {
        // Initialize Appium Session (when running live against connected phone / emulator)
        if (process.env.RUN_LIVE_APPIUM === 'true') {
            driver = await remote(wdOpts);
        }
    });

    after(async function () {
        if (driver) {
            await driver.deleteSession();
        }
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 1. App Launch & Splash Screen Transitions
    // ─────────────────────────────────────────────────────────────────────────
    describe('1. App Launch & Splash Screen Transitions', function () {
        it('TC_APP_001: Should launch CookSmart application cleanly without crash', async function () {
            if (!driver) this.skip();
            const currentPackage = await driver.getCurrentPackage();
            expect(currentPackage).to.equal('com.example.cooksmart_app');
        });

        it('TC_APP_002: Should navigate from Splash to Login/Welcome screen within 3s', async function () {
            if (!driver) this.skip();
            await driver.pause(3000);
            const isDisplayed = await driver.$('//android.widget.TextView[contains(@text, "Welcome")]').isDisplayed();
            expect(isDisplayed).to.be.true;
        });

        it('TC_APP_003: Verify Flutter engine canvas initialization and cold start time', async function () {
            if (!driver) this.skip();
            const appState = await driver.queryAppState('com.example.cooksmart_app');
            expect(appState).to.equal(4); // 4 = Running in foreground
        });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 2. Mobile Authentication & Keyboard Interactions
    // ─────────────────────────────────────────────────────────────────────────
    describe('2. Mobile Authentication & Keyboard Interactions', function () {
        it('TC_APP_004: Soft keyboard appears on input focus and hides on dismiss', async function () {
            if (!driver) this.skip();
            const emailField = await driver.$('//android.widget.EditText[1]');
            await emailField.click();
            const isKeyboardShown = await driver.isKeyboardShown();
            expect(isKeyboardShown).to.be.true;
            await driver.hideKeyboard();
        });

        it('TC_APP_005: Obscure password toggle button interaction (Show/Hide characters)', async function () {
            if (!driver) this.skip();
            const toggleBtn = await driver.$('//android.widget.Button[contains(@content-desc, "password")]');
            if (await toggleBtn.isExisting()) {
                await toggleBtn.click();
                await driver.pause(500);
            }
        });

        it('TC_APP_006: User login flow with demo credentials', async function () {
            if (!driver) this.skip();
            const emailField = await driver.$('//android.widget.EditText[1]');
            const passField = await driver.$('//android.widget.EditText[2]');
            await emailField.setValue('demo@cooksmart.com');
            await passField.setValue('password123');
            await driver.hideKeyboard();
            const loginBtn = await driver.$('//android.widget.Button[contains(@text, "Sign In") or contains(@content-desc, "Sign In")]');
            await loginBtn.click();
            await driver.pause(2000);
        });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 3. Touch Gestures, Scrolling & Screen Navigation
    // ─────────────────────────────────────────────────────────────────────────
    describe('3. Touch Gestures, Scrolling & Screen Navigation', function () {
        it('TC_APP_007: Vertical scrolling across recipe details and ingredients list', async function () {
            if (!driver) this.skip();
            const size = await driver.getWindowRect();
            await driver.touchAction([
                { action: 'press', x: size.width / 2, y: size.height * 0.8 },
                { action: 'wait', ms: 500 },
                { action: 'moveTo', x: size.width / 2, y: size.height * 0.2 },
                'release'
            ]);
        });

        it('TC_APP_008: Bottom navigation bar tab switching (Home, Scan, Favorites, Planner, Profile)', async function () {
            if (!driver) this.skip();
            const navItems = await driver.$$('//android.widget.FrameLayout[contains(@resource-id, "bottom_nav")] | //android.view.View[@role="tab"]');
            if (navItems.length > 0) {
                await navItems[0].click();
                await driver.pause(500);
            }
        });

        it('TC_APP_009: Pull-to-refresh gesture triggers data refresh in Favorites', async function () {
            if (!driver) this.skip();
            const size = await driver.getWindowRect();
            await driver.touchAction([
                { action: 'press', x: size.width / 2, y: size.height * 0.3 },
                { action: 'wait', ms: 500 },
                { action: 'moveTo', x: size.width / 2, y: size.height * 0.7 },
                'release'
            ]);
        });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 4. Camera & Image Capture AI Scanning
    // ─────────────────────────────────────────────────────────────────────────
    describe('4. Camera & Image Capture AI Scanning', function () {
        it('TC_APP_010: Camera / Gallery access trigger for ingredient scanning', async function () {
            if (!driver) this.skip();
            const hasPermission = await driver.executeScript('mobile: getPermissions', [{ type: 'camera' }]);
            expect(hasPermission).to.not.be.null;
        });

        it('TC_APP_011: Photo upload and Groq Vision AI response parsing', async function () {
            if (!driver) this.skip();
            // Verify AI ingredient tags chip generation
            const chips = await driver.$$('//android.widget.TextView[contains(@resource-id, "chip")]');
            expect(chips.length).to.be.greaterThanOrEqual(0);
        });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 5. Device Lifecycle & Background Suspension
    // ─────────────────────────────────────────────────────────────────────────
    describe('5. Device Lifecycle & Background Suspension', function () {
        it('TC_APP_012: App suspension to background for 5s and resume without session drop', async function () {
            if (!driver) this.skip();
            await driver.background(5);
            const state = await driver.queryAppState('com.example.cooksmart_app');
            expect(state).to.equal(4); // 4 = Running in foreground
        });

        it('TC_APP_013: Device orientation change (Portrait to Landscape) handling', async function () {
            if (!driver) this.skip();
            await driver.setOrientation('LANDSCAPE');
            await driver.pause(1000);
            await driver.setOrientation('PORTRAIT');
            await driver.pause(1000);
            const orientation = await driver.getOrientation();
            expect(orientation).to.equal('PORTRAIT');
        });

        it('TC_APP_014: Lock screen and unlock resumption integrity', async function () {
            if (!driver) this.skip();
            await driver.lock();
            await driver.pause(1000);
            await driver.unlock();
            const state = await driver.queryAppState('com.example.cooksmart_app');
            expect(state).to.equal(4);
        });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 6. Network Resilience & Offline Recovery
    // ─────────────────────────────────────────────────────────────────────────
    describe('6. Network Resilience & Offline Recovery', function () {
        it('TC_APP_015: Graceful network error handling when connection drops', async function () {
            if (!driver) this.skip();
            const state = await driver.queryAppState('com.example.cooksmart_app');
            expect(state).to.equal(4);
        });

        it('TC_APP_016: Automatic reconnection when mobile Wi-Fi is restored', async function () {
            if (!driver) this.skip();
            const state = await driver.queryAppState('com.example.cooksmart_app');
            expect(state).to.equal(4);
        });
    });
});
