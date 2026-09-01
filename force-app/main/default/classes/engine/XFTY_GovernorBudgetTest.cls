/**
 * Coverage for `XFTY_GovernorBudget` - the "generation ate a large share of a
 * governor limit" warning, its `XFTY_Settings__c` thresholds, and its off
 * switch. Uses DML rows as the counter, with the warn thresholds turned right
 * down via `XFTY_Settings__c` so a small `insert` crosses them - a full-size
 * bulk insert is needlessly slow on a shared CI runner and can itself exhaust
 * the CPU limit before the assertion runs.
 */
@IsTest
private class XFTY_GovernorBudgetTest {
    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;

    @IsTest
    static void cheapGenerationProducesNoWarnings() {
        // Arrange
        XFTY_GovernorBudget budget = new XFTY_GovernorBudget();

        // Act
        insert new Account(Name = 'One');

        // Assert
        Assert.isTrue(budget.warnings().isEmpty(), budget.warnings().toString());
    }

    @IsTest
    static void pastTheSoftThresholdWarns() {
        // Arrange - warn past 10% of any limit; a 1 500-row insert is 15% of the 10 000 DML-row limit
        insert new XFTY_Settings__c(SetupOwnerId = UserInfo.getOrganizationId(), LimitWarnSoftPercent__c = 10);
        XFTY_GovernorBudget budget = new XFTY_GovernorBudget();

        // Act
        System.runAs(TEST_ADMIN) {
            insert accountsNamed(1500);
        }

        // Assert
        Assert.isTrue(warningFor('DML rows', budget).contains('a large part of'), budget.warnings().toString());
    }

    @IsTest
    static void pastTheHardThresholdWarnsHarder() {
        // Arrange - hard threshold at 10%; 1 500 rows is 15%, past it
        insert new XFTY_Settings__c(
                SetupOwnerId = UserInfo.getOrganizationId(),
                LimitWarnSoftPercent__c = 5,
                LimitWarnHardPercent__c = 10
        );
        XFTY_GovernorBudget budget = new XFTY_GovernorBudget();

        // Act
        System.runAs(TEST_ADMIN) {
            insert accountsNamed(1500);
        }

        // Assert
        Assert.isTrue(warningFor('DML rows', budget).contains('most of'), budget.warnings().toString());
    }

    @IsTest
    static void aCustomSoftThresholdIsHonoured() {
        // Arrange - an 8% insert is under a default threshold but over a 5% setting
        insert new XFTY_Settings__c(SetupOwnerId = UserInfo.getOrganizationId(), LimitWarnSoftPercent__c = 5);
        XFTY_GovernorBudget budget = new XFTY_GovernorBudget();

        // Act
        System.runAs(TEST_ADMIN) {
            insert accountsNamed(800);
        }

        // Assert
        Assert.isTrue(warningFor('DML rows', budget).contains('a large part of'), budget.warnings().toString());
    }

    @IsTest
    static void disabledSuppressesEveryWarning() {
        // Arrange - past the (lowered) soft threshold, but warnings are switched off
        insert new XFTY_Settings__c(
                SetupOwnerId = UserInfo.getOrganizationId(),
                LimitWarningsDisabled__c = true,
                LimitWarnSoftPercent__c = 5
        );
        XFTY_GovernorBudget budget = new XFTY_GovernorBudget();

        // Act
        System.runAs(TEST_ADMIN) {
            insert accountsNamed(1500);
        }

        // Assert
        Assert.isTrue(budget.warnings().isEmpty(), 'LimitWarningsDisabled__c silences the warning');
        budget.warnIfExpensive();   // must still run cleanly
    }

    private static String warningFor(String counter, XFTY_GovernorBudget budget) {
        for (String warning : budget.warnings()) {
            if (warning.contains(counter)) {
                return warning;
            }
        }
        return '';
    }

    private static List<Account> accountsNamed(Integer howMany) {
        List<Account> newAccounts = new List<Account>();
        for (Integer i = 0; i < howMany; i++) {
            newAccounts.add(new Account(Name = 'Bulk ' + i));
        }
        return newAccounts;
    }
}
