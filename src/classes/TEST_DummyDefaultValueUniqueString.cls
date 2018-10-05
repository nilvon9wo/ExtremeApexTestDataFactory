@IsTest 
public class TEST_DummyDefaultValueUniqueString implements TEST_DummyDefaultValueIntf {
    private String prefix;
    private static Integer counter = 1; 
    
    public TEST_DummyDefaultValueUniqueString(String prefix) {
    	this.prefix = prefix;
    }  
    
    public Object get() {
    	return this.prefix + ' ' + counter++;
    } 
}