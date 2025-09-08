#!/usr/bin/env node

/**
 * FTH-GOLD Coverage Monitoring Script
 * Monitors reserve coverage ratio and triggers alerts
 */

const { ethers } = require('ethers');
const fs = require('fs');
const path = require('path');

// Load environment variables
require('dotenv').config();

// Configuration
const CONFIG = {
    network: process.env.NETWORK || 'sepolia',
    rpcUrl: process.env.RPC_SEPOLIA,
    reserveOracleAddress: process.env.RESERVE_ORACLE_ADDRESS,
    coverageFloorBps: parseInt(process.env.COVERAGE_FLOOR_BPS) || 10000, // 100%
    warningThresholdBps: parseInt(process.env.COVERAGE_WARNING_BPS) || 10200, // 102%
    checkIntervalMs: 60000, // 1 minute
    alertWebhook: process.env.DISCORD_WEBHOOK || process.env.SLACK_WEBHOOK,
    logFile: './logs/coverage-monitor.log'
};

// ABI for ReserveOracle (simplified)
const RESERVE_ORACLE_ABI = [
    'function getCoverageRatio() external view returns (uint256)',
    'function getLatestData() external view returns (tuple(uint256 goldReservesKG, uint256 tokensIssued, uint256 coverageRatio, uint256 timestamp, address source))',
    'function isCoverageHealthy() external view returns (bool isHealthy, uint256 coverage)'
];

class CoverageMonitor {
    constructor() {
        this.provider = new ethers.JsonRpcProvider(CONFIG.rpcUrl);
        this.reserveOracle = new ethers.Contract(
            CONFIG.reserveOracleAddress,
            RESERVE_ORACLE_ABI,
            this.provider
        );
        this.lastAlertTime = 0;
        this.lastCoverage = 0;
        this.alertCooldownMs = 300000; // 5 minutes between alerts
    }

    async initialize() {
        try {
            // Test connection
            const network = await this.provider.getNetwork();
            this.log(`Connected to network: ${network.name} (Chain ID: ${network.chainId})`);
            
            // Test contract connection
            const coverage = await this.reserveOracle.getCoverageRatio();
            this.log(`Initial coverage ratio: ${this.formatCoverage(coverage)}`);
            
            return true;
        } catch (error) {
            this.log(`Failed to initialize: ${error.message}`, 'ERROR');
            return false;
        }
    }

    async checkCoverage() {
        try {
            const [isHealthy, coverageRatio] = await this.reserveOracle.isCoverageHealthy();
            const latestData = await this.reserveOracle.getLatestData();
            
            const coverage = {
                ratio: parseInt(coverageRatio.toString()),
                healthy: isHealthy,
                goldKG: ethers.formatEther(latestData.goldReservesKG),
                tokensIssued: ethers.formatEther(latestData.tokensIssued),
                timestamp: new Date(parseInt(latestData.timestamp.toString()) * 1000),
                lastUpdate: new Date()
            };
            
            this.logCoverageData(coverage);
            this.checkAlertConditions(coverage);
            
            this.lastCoverage = coverage.ratio;
            return coverage;
            
        } catch (error) {
            this.log(`Error checking coverage: ${error.message}`, 'ERROR');
            return null;
        }
    }

    logCoverageData(coverage) {
        const message = [
            `Coverage: ${this.formatCoverage(coverage.ratio)}`,
            `Gold: ${coverage.goldKG} kg`,
            `Tokens: ${coverage.tokensIssued}`,
            `Status: ${coverage.healthy ? '✅ Healthy' : '❌ Unhealthy'}`,
            `Data Age: ${this.getDataAge(coverage.timestamp)}`
        ].join(' | ');
        
        this.log(message);
    }

    checkAlertConditions(coverage) {
        const now = Date.now();
        const shouldAlert = (now - this.lastAlertTime) > this.alertCooldownMs;
        
        // Critical: Coverage below floor
        if (coverage.ratio < CONFIG.coverageFloorBps && shouldAlert) {
            this.sendAlert('CRITICAL', `Coverage BREACH: ${this.formatCoverage(coverage.ratio)} < ${this.formatCoverage(CONFIG.coverageFloorBps)}`, coverage);
            this.lastAlertTime = now;
            return;
        }
        
        // Warning: Coverage below warning threshold
        if (coverage.ratio < CONFIG.warningThresholdBps && coverage.ratio >= CONFIG.coverageFloorBps && shouldAlert) {
            this.sendAlert('WARNING', `Coverage LOW: ${this.formatCoverage(coverage.ratio)} < ${this.formatCoverage(CONFIG.warningThresholdBps)}`, coverage);
            this.lastAlertTime = now;
            return;
        }
        
        // Info: Coverage recovered
        if (this.lastCoverage < CONFIG.warningThresholdBps && coverage.ratio >= CONFIG.warningThresholdBps && shouldAlert) {
            this.sendAlert('INFO', `Coverage RECOVERED: ${this.formatCoverage(coverage.ratio)}`, coverage);
            this.lastAlertTime = now;
        }
    }

    async sendAlert(level, message, coverage) {
        const alertData = {
            level,
            message,
            coverage: coverage.ratio,
            goldKG: coverage.goldKG,
            tokensIssued: coverage.tokensIssued,
            timestamp: new Date().toISOString(),
            network: CONFIG.network
        };
        
        this.log(`${level} ALERT: ${message}`, level);
        
        // Send webhook notification
        if (CONFIG.alertWebhook) {
            try {
                await this.sendWebhookAlert(alertData);
            } catch (error) {
                this.log(`Failed to send webhook: ${error.message}`, 'ERROR');
            }
        }
        
        // Save alert to file
        await this.saveAlert(alertData);
    }

    async sendWebhookAlert(alertData) {
        const webhook = require('https');
        const url = new URL(CONFIG.alertWebhook);
        
        const color = {
            'CRITICAL': 15158332, // Red
            'WARNING': 15105570,  // Orange
            'INFO': 3447003       // Blue
        }[alertData.level] || 0;
        
        const payload = {
            embeds: [{
                title: `🏛️ FTH-GOLD Coverage Alert`,
                description: alertData.message,
                color: color,
                fields: [
                    { name: 'Coverage Ratio', value: this.formatCoverage(alertData.coverage), inline: true },
                    { name: 'Gold Reserves', value: `${alertData.goldKG} kg`, inline: true },
                    { name: 'Tokens Issued', value: alertData.tokensIssued, inline: true },
                    { name: 'Network', value: alertData.network, inline: true },
                    { name: 'Timestamp', value: alertData.timestamp, inline: true }
                ],
                footer: { text: 'FTH-GOLD Coverage Monitor' }
            }]
        };
        
        return new Promise((resolve, reject) => {
            const req = webhook.request({
                hostname: url.hostname,
                path: url.pathname,
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                }
            }, (res) => {
                if (res.statusCode >= 200 && res.statusCode < 300) {
                    resolve();
                } else {
                    reject(new Error(`Webhook returned ${res.statusCode}`));
                }
            });
            
            req.on('error', reject);
            req.write(JSON.stringify(payload));
            req.end();
        });
    }

    async saveAlert(alertData) {
        const alertFile = './logs/coverage-alerts.jsonl';
        const alertLine = JSON.stringify(alertData) + '\n';
        
        try {
            await fs.promises.mkdir(path.dirname(alertFile), { recursive: true });
            await fs.promises.appendFile(alertFile, alertLine);
        } catch (error) {
            this.log(`Failed to save alert: ${error.message}`, 'ERROR');
        }
    }

    formatCoverage(bps) {
        return `${(bps / 100).toFixed(2)}%`;
    }

    getDataAge(timestamp) {
        const ageMs = Date.now() - timestamp.getTime();
        const ageMinutes = Math.floor(ageMs / 60000);
        
        if (ageMinutes < 1) return 'Just now';
        if (ageMinutes < 60) return `${ageMinutes}m ago`;
        if (ageMinutes < 1440) return `${Math.floor(ageMinutes / 60)}h ago`;
        return `${Math.floor(ageMinutes / 1440)}d ago`;
    }

    log(message, level = 'INFO') {
        const timestamp = new Date().toISOString();
        const logMessage = `[${timestamp}] [${level}] ${message}`;
        
        console.log(logMessage);
        
        // Save to log file
        try {
            fs.promises.mkdir(path.dirname(CONFIG.logFile), { recursive: true }).then(() => {
                fs.promises.appendFile(CONFIG.logFile, logMessage + '\n');
            });
        } catch (error) {
            // Silent fail for logging
        }
    }

    async start() {
        this.log('🚀 Starting FTH-GOLD Coverage Monitor');
        this.log(`Network: ${CONFIG.network}`);
        this.log(`Check Interval: ${CONFIG.checkIntervalMs / 1000}s`);
        this.log(`Coverage Floor: ${this.formatCoverage(CONFIG.coverageFloorBps)}`);
        this.log(`Warning Threshold: ${this.formatCoverage(CONFIG.warningThresholdBps)}`);
        
        const initialized = await this.initialize();
        if (!initialized) {
            this.log('Failed to initialize monitor', 'ERROR');
            process.exit(1);
        }
        
        // Initial check
        await this.checkCoverage();
        
        // Set up periodic checking
        setInterval(async () => {
            await this.checkCoverage();
        }, CONFIG.checkIntervalMs);
        
        this.log('✅ Coverage monitor started successfully');
    }

    async generateReport() {
        this.log('📊 Generating coverage report...');
        
        try {
            const coverage = await this.checkCoverage();
            if (!coverage) return;
            
            const report = {
                timestamp: new Date().toISOString(),
                network: CONFIG.network,
                coverage: {
                    ratio: this.formatCoverage(coverage.ratio),
                    healthy: coverage.healthy,
                    goldReserves: `${coverage.goldKG} kg`,
                    tokensIssued: coverage.tokensIssued,
                    lastUpdate: coverage.timestamp.toISOString()
                },
                thresholds: {
                    floor: this.formatCoverage(CONFIG.coverageFloorBps),
                    warning: this.formatCoverage(CONFIG.warningThresholdBps)
                }
            };
            
            const reportFile = `./reports/coverage-report-${new Date().toISOString().split('T')[0]}.json`;
            await fs.promises.mkdir(path.dirname(reportFile), { recursive: true });
            await fs.promises.writeFile(reportFile, JSON.stringify(report, null, 2));
            
            this.log(`Report saved to: ${reportFile}`);
            console.log(JSON.stringify(report, null, 2));
            
        } catch (error) {
            this.log(`Failed to generate report: ${error.message}`, 'ERROR');
        }
    }
}

// Main execution
async function main() {
    const monitor = new CoverageMonitor();
    
    const command = process.argv[2];
    
    switch (command) {
        case 'report':
            await monitor.generateReport();
            process.exit(0);
            break;
        
        case 'check':
            await monitor.initialize();
            await monitor.checkCoverage();
            process.exit(0);
            break;
        
        default:
            await monitor.start();
            break;
    }
}

// Handle process termination
process.on('SIGTERM', () => {
    console.log('📴 Coverage monitor shutting down...');
    process.exit(0);
});

process.on('SIGINT', () => {
    console.log('📴 Coverage monitor shutting down...');
    process.exit(0);
});

// Handle unhandled rejections
process.on('unhandledRejection', (reason, promise) => {
    console.error('Unhandled Rejection at:', promise, 'reason:', reason);
    process.exit(1);
});

if (require.main === module) {
    main().catch(error => {
        console.error('Fatal error:', error);
        process.exit(1);
    });
}

module.exports = CoverageMonitor;