import { parse } from '../Src/parsing'
import { expect, test } from '@jest/globals'
import { readFileSync } from 'fs'

test (`parse example1.yml correctly`, () => {
    const path = 'example1.yml'
    const repo = 'empty'
    const content = readFileSync(`__tests__/${path}`, 'utf8').toString().split("\r\n")
    const actions = parse(content, path, repo)
    console.log(`Found [${actions.length}] actions`)
    
    expect(actions.length).toBe(5)
})

test (`parse example2.yml correctly`, () => {
    const path = 'example2.yml'
    const repo = 'empty'
    const content = readFileSync(`__tests__/${path}`, 'utf8').toString().split("\r\n")
    const actions = parse(content, path, repo)
    console.log(`Found [${actions.length}] actions`)
    
    expect(actions.length).toBe(0)
})

test (`parse example3.yml correctly`, () => {
    const path = 'example3.yml'
    const repo = 'empty'
    const content = readFileSync(`__tests__/${path}`, 'utf8').toString().split("\r\n")
    const actions = parse(content, path, repo)
    console.log(`Found [${actions.length}] actions`)
    
    expect(actions.length).toBe(4)
})

test (`parse example4.yml correctly`, () => {
    const path = 'example4.yml'
    const repo = 'empty'
    const content = readFileSync(`__tests__/${path}`, 'utf8').toString().split("\r\n")
    const actions = parse(content, path, repo)
    console.log(`Found [${actions.length}] actions`)
    
    expect(actions.length).toBe(1)
})