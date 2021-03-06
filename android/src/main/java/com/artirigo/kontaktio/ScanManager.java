package com.artirigo.kontaktio;

import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactMethod;

import com.kontakt.sdk.android.ble.connection.OnServiceReadyListener;
import com.kontakt.sdk.android.ble.manager.ProximityManager;

public class ScanManager {
    private ProximityManager proximityManager;

    ScanManager(ProximityManager proximityManager) {
        this.proximityManager = proximityManager;
    }

    void startScanning(Promise promise) {
        try {
            if (proximityManager.isConnected()) {
                proximityManager.startScanning();
            } else {
                // connect if not connected yet
                proximityManager.connect(new OnServiceReadyListener() {
                    @Override
                    public void onServiceReady() {
                        proximityManager.startScanning();
                    }
                });
            }
            promise.resolve(null);
        } catch (Exception e) {
            promise.reject(Constants.EXCEPTION, e);
        }
    }

    void stopScanning(Promise promise) {
        try {
            if (proximityManager.isScanning()) {
                proximityManager.stopScanning();
                promise.resolve(null);
            } else {
                throw new Exception("Cannot stop scanning because device is currently not scanning.");
            }
        } catch (Exception e) {
            promise.reject(Constants.EXCEPTION, e);
        }
    }

    void restartScanning(Promise promise) {
        try {
            if (proximityManager.isScanning()) {
                proximityManager.restartScanning();
            } else {
                // start scanning if device is not scanning already
                if (proximityManager.isConnected()) {
                    proximityManager.startScanning();
                } else {
                    proximityManager.connect(new OnServiceReadyListener() {
                        @Override
                        public void onServiceReady() {
                            proximityManager.startScanning();
                        }
                    });
                }
            }
            promise.resolve(null);
        } catch (Exception e) {
            promise.reject(Constants.EXCEPTION, e);
        }
    }

    void isScanning(Promise promise) {
        try {
            boolean isScanning = proximityManager.isScanning();
            promise.resolve(isScanning);
        } catch (Exception e) {
            promise.reject(Constants.EXCEPTION, e);
        }
    }
}
