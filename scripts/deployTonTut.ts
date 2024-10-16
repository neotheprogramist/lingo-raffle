import { toNano } from '@ton/core';
import { TonTut } from '../wrappers/TonTut';
import { NetworkProvider } from '@ton/blueprint';

export async function run(provider: NetworkProvider) {
    const randomInt = BigInt(Math.floor(Math.random()*1000000));
    const tonTut = provider.open(await TonTut.fromInit(randomInt));

    await tonTut.send(
        provider.sender(),
        {
            value: toNano('0.05'),
        },
        {
            $$type: 'Deploy',
            queryId: 0n,
        }
    );

    await provider.waitForDeploy(tonTut.address);

    // console.log("Id", await tonTut.getId());

    // run methods on `tonTut`
}
