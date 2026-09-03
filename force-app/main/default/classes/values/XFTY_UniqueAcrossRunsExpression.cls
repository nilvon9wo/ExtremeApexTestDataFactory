/**
 * A value that is unique **across transactions, orgs and runs** - not just within
 * one transaction like {@link XFTY_UniqueStringExpression} (whose counter resets
 * every transaction).
 *
 * The difference matters only when the record is *persisted*: two seed runs each
 * generating `test.username.example1@example.com` collide on the second insert.
 * Used by {@link XFTY_DefaultUserDataProvider} for `Username` /
 * `FederationIdentifier`, which the platform requires to be globally unique.
 *
 * `prefix` + a per-transaction token (time + randomness) + a counter + `suffix`.
 * Keep `prefix` + `suffix` short - the token adds ~14 characters and a `Username`
 * caps at 80.
 */
@IsTest
public class XFTY_UniqueAcrossRunsExpression implements XFTY_ValueExpressionIntf {

    private static final String RUN_TOKEN = buildRunToken();
    private static Integer counter = 1;

    private final String prefix;
    private final String suffix;

    public XFTY_UniqueAcrossRunsExpression(String prefix, String suffix) {
        this.prefix = (prefix == null) ? '' : prefix;
        this.suffix = (suffix == null) ? '' : suffix;
    }

    public Object get() {
        return this.prefix + RUN_TOKEN + counter++ + this.suffix;
    }

    private static String buildRunToken() {
        String nowMillis = String.valueOf(Datetime.now().getTime());
        String entropy = String.valueOf(Math.abs(Crypto.getRandomInteger()));
        return nowMillis.right(9) + entropy.right(5);
    }
}
