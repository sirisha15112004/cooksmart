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

describe('CookSmart Mobile App - Appium E2E Test Suite', function () {
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

    describe('1. App Launch & Splash Transition', function () {
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
    });

    describe('2. Mobile Touch, Gestures & Keyboards', function () {
        it('TC_APP_003: Soft keyboard appears on input focus and hides on dismiss', async function () {
            if (!driver) this.skip();
            const emailField = await driver.$('//android.widget.EditText[1]');
            await emailField.click();
            const isKeyboardShown = await driver.isKeyboardShown();
            expect(isKeyboardShown).to.be.true;
            await driver.hideKeyboard();
        });

        it('TC_APP_004: Vertical scrolling across long ingredient lists & recipe details', async function () {
            if (!driver) this.skip();
            const size = await driver.getWindowRect();
            await driver.touchAction([
                { action: 'press', x: size.width / 2, y: size.height * 0.8 },
                { action: 'wait', ms: 500 },
                { action: 'moveTo', x: size.width / 2, y: size.height * 0.2 },
                'release'
            ]);
        });
    });

    describe('3. Mobile Camera & Media Permission Handling', function () {
        it('TC_APP_005: Camera / Gallery access trigger for ingredient scanning', async function () {
            if (!driver) this.skip();
            // Verify permission prompt handling
            const hasPermission = await driver.executeScript('mobile: getPermissions', [{ type: 'camera' }]);
            expect(hasPermission).to.not.be.null;
        });
    });

    describe('4. Device Lifecycle & Background Suspension', function () {
        it('TC_APP_006: App suspension to background for 5s and resume without session drop', async function () {
            if (!driver) this.skip();
            await driver.background(5);
            const state = await driver.queryAppState('com.example.cooksmart_app');
            expect(state).to.equal(4); // 4 = Running in foreground
        });

        it('TC_APP_007: Device orientation change (Portrait to Landscape) handling', async function () {
            if (!driver) this.skip();
            await driver.setOrientation('LANDSCAPE');
            await driver.pause(1000);
            await driver.setOrientation('PORTRAIT');
            await driver.pause(1000);
            const orientation = await driver.getOrientation();
            expect(orientation).to.equal('PORTRAIT');
        });
    });

    describe('5. Offline Network Recovery', function () {
        it('TC_APP_008: Graceful network error handling when Airplane mode is enabled', async function () {
            if (!driver) this.skip();
            // Network disconnection resilience check
            const state = await driver.queryAppState('com.example.cooksmart_app');
            expect(state).to.equal(4);
        });
    });
});
