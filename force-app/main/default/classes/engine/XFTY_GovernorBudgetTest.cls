/**
 * Coverage for `XFTY_GovernorBudget` - the "generation ate a large share of a
 * governor limit" warning. Uses DML rows (10 000 limit) as the counter that is
 * cheap to push with one `insert`.
 */
@IsTest
private class XFTY_GovernorBudgetTest {
    private static final User TEST_ADMIN = XFTY_DefaultUserDataProvider.TEST_ADMIN_USER;

    @IsTest
    static void cheapGenerationProducesNoWarnings() {
        XFTY_GovernorBudget budget = new XFTY_GovernorBudget();
        insert new Account(Name = 'One');

        Assert.isTrue(budget.warnings().isEmpty(), budget.warnings().toString());
    }

    @IsTest
    static void overHalfALimitWarns() {
        XFTY_GovernorBudget budget = new XFTY_GovernorBudget();
        System.runAs(TEST_ADMIN) {
            insert accountsNamed(6000);   // 6000 / 10000 DML rows -> over half
        }

        Assert.isTrue(warningFor('DML rows', budget).contains('over half'), budget.warnings().toString());
    }

    @IsTest
    static void mostOfALimitWarnsHarder() {
        XFTY_GovernorBudget budget = new XFTY_GovernorBudget();
        System.runAs(TEST_ADMIN) {
            insert accountsNamed(9000);   // 9000 / 10000 DML rows -> most of
        }

        Assert.isTrue(warningFor('DML rows', budget).contains('most of'), budget.warnings().toString());
    }

    private static String warningFor(String counter, XFTY_GovernorBudget budget) {
        for (String warning : budget.warnings()) {
            if (warning.contains(counter)) {
                return warning;
            }
        }
        return '';
    }

    @IsTest
    static void warnIfExpensiveRunsWithoutThrowing() {
        XFTY_GovernorBudget budget = new XFTY_GovernorBudget();
        insert new Account(Name = 'One');

        budget.warnIfExpensive();   // logs (nothing here to log) - must not throw
    }

    private static List<Account> accountsNamed(Integer howMany) {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < howMany; i++) {
            accounts.add(new Account(Name = 'Bulk ' + i));
        }
        return accounts;
    }
}
